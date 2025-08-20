#!/bin/bash

# MediQ Kubernetes Scaling Script
# Usage: ./scale.sh [service] [replicas] [staging|production]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parameters
SERVICE=${1}
REPLICAS=${2}
ENVIRONMENT=${3:-staging}
NAMESPACE="mediq-${ENVIRONMENT}"

# Available services
SERVICES=(
    "api-gateway"
    "user-service"
    "ocr-service"
    "ocr-engine-service"
    "patient-queue-service"
    "all"
)

# Default replica counts per service
declare -A DEFAULT_REPLICAS=(
    ["api-gateway"]="3"
    ["user-service"]="3"
    ["ocr-service"]="2"
    ["ocr-engine-service"]="2"
    ["patient-queue-service"]="3"
)

# Function to show usage
show_usage() {
    echo "Usage: $0 [service] [replicas] [environment]"
    echo ""
    echo "Parameters:"
    echo "  service     - Service to scale (${SERVICES[*]})"
    echo "  replicas    - Number of replicas to scale to"
    echo "  environment - Target environment (staging|production) [default: staging]"
    echo ""
    echo "Examples:"
    echo "  $0 api-gateway 5 production"
    echo "  $0 user-service 2 staging"
    echo "  $0 all default staging"
    echo ""
    echo "Special commands:"
    echo "  $0 status staging                    # Show current scaling status"
    echo "  $0 all default staging               # Reset all services to default replicas"
    echo "  $0 all 0 staging                     # Scale down all services to 0 (maintenance mode)"
    exit 1
}

# Validate parameters
if [ -z "$SERVICE" ]; then
    echo -e "${RED}Error: Service parameter is required${NC}"
    show_usage
fi

# Special case for status
if [ "$SERVICE" == "status" ]; then
    ENVIRONMENT=${2:-staging}
    NAMESPACE="mediq-${ENVIRONMENT}"
    
    echo -e "${GREEN}📊 Current scaling status for $ENVIRONMENT:${NC}"
    echo -e "${YELLOW}Namespace: $NAMESPACE${NC}"
    echo ""
    
    for service in "${!DEFAULT_REPLICAS[@]}"; do
        if kubectl get deployment $service -n $NAMESPACE &> /dev/null; then
            current=$(kubectl get deployment $service -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "N/A")
            ready=$(kubectl get deployment $service -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            default=${DEFAULT_REPLICAS[$service]}
            
            if [ "$current" == "$ready" ] && [ "$current" -gt "0" ]; then
                status_icon="✅"
            elif [ "$current" == "0" ]; then
                status_icon="🔴"
            else
                status_icon="⚠️"
            fi
            
            echo -e "$status_icon $service: $ready/$current (default: $default)"
        else
            echo -e "❌ $service: Not found"
        fi
    done
    
    echo ""
    echo -e "${GREEN}HPA Status:${NC}"
    kubectl get hpa -n $NAMESPACE 2>/dev/null || echo "No HPA found"
    
    exit 0
fi

# Validate service
if [[ ! " ${SERVICES[@]} " =~ " ${SERVICE} " ]]; then
    echo -e "${RED}Error: Invalid service. Available services: ${SERVICES[*]}${NC}"
    exit 1
fi

if [ -z "$REPLICAS" ]; then
    echo -e "${RED}Error: Replicas parameter is required${NC}"
    show_usage
fi

# Validate replicas (must be number or 'default')
if [[ ! "$REPLICAS" =~ ^[0-9]+$ ]] && [ "$REPLICAS" != "default" ]; then
    echo -e "${RED}Error: Replicas must be a number or 'default'${NC}"
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(staging|production)$ ]]; then
    echo -e "${RED}Error: Environment must be 'staging' or 'production'${NC}"
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

# Check if we can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster. Please check your kubeconfig.${NC}"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${RED}Error: Namespace $NAMESPACE does not exist${NC}"
    exit 1
fi

# Function to scale a service
scale_service() {
    local service=$1
    local target_replicas=$2
    
    # Handle default replicas
    if [ "$target_replicas" == "default" ]; then
        target_replicas=${DEFAULT_REPLICAS[$service]}
    fi
    
    echo -e "${YELLOW}⚖️  Scaling $service to $target_replicas replicas...${NC}"
    
    # Check if deployment exists
    if ! kubectl get deployment $service -n $NAMESPACE &> /dev/null; then
        echo -e "${RED}❌ Deployment $service not found in namespace $NAMESPACE${NC}"
        return 1
    fi
    
    # Get current replica count
    local current_replicas=$(kubectl get deployment $service -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    
    if [ "$current_replicas" == "$target_replicas" ]; then
        echo -e "${GREEN}✅ $service is already scaled to $target_replicas replicas${NC}"
        return 0
    fi
    
    # Perform scaling
    if kubectl scale deployment $service --replicas=$target_replicas -n $NAMESPACE; then
        echo -e "${GREEN}✅ Scaling initiated for $service (${current_replicas} → ${target_replicas})${NC}"
        
        # Wait for scaling to complete
        echo -e "${YELLOW}⏳ Waiting for scaling to complete...${NC}"
        
        if [ "$target_replicas" -gt "0" ]; then
            # Scaling up - wait for pods to be ready
            if kubectl rollout status deployment/$service -n $NAMESPACE --timeout=300s; then
                echo -e "${GREEN}✅ Scaling completed successfully for $service${NC}"
                
                # Show new status
                kubectl get pods -l app=$service -n $NAMESPACE
            else
                echo -e "${RED}❌ Scaling failed for $service${NC}"
                return 1
            fi
        else
            # Scaling down to 0 - just wait a bit
            sleep 10
            echo -e "${GREEN}✅ Service $service scaled down to 0${NC}"
        fi
    else
        echo -e "${RED}❌ Failed to initiate scaling for $service${NC}"
        return 1
    fi
}

# Function to scale all services
scale_all_services() {
    local target_replicas=$1
    local failed_services=()
    
    # Handle default scaling
    if [ "$target_replicas" == "default" ]; then
        echo -e "${GREEN}🔄 Scaling all services to default replica counts...${NC}"
    elif [ "$target_replicas" == "0" ]; then
        echo -e "${YELLOW}⚠️  Scaling all services to 0 (maintenance mode)${NC}"
        echo -e "${RED}⚠️  This will make your application unavailable!${NC}"
        echo -e "${YELLOW}Are you sure? (y/N)${NC}"
        read -r response
        if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo -e "${YELLOW}Scaling cancelled${NC}"
            return 0
        fi
    else
        echo -e "${GREEN}🔄 Scaling all services to $target_replicas replicas...${NC}"
    fi
    
    # Scale services in order (infrastructure services first if scaling up, last if scaling down)
    local services_list=("user-service" "ocr-engine-service" "ocr-service" "patient-queue-service" "api-gateway")
    
    if [ "$target_replicas" == "0" ]; then
        # Reverse order for scaling down (API Gateway first)
        services_list=("api-gateway" "patient-queue-service" "ocr-service" "ocr-engine-service" "user-service")
    fi
    
    for service in "${services_list[@]}"; do
        echo -e "${GREEN}Processing $service...${NC}"
        
        local service_replicas=$target_replicas
        if [ "$target_replicas" == "default" ]; then
            service_replicas=${DEFAULT_REPLICAS[$service]}
        fi
        
        if ! scale_service $service $service_replicas; then
            failed_services+=($service)
        fi
        
        # Add delay between services
        sleep 5
    done
    
    # Report results
    if [ ${#failed_services[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ All services scaled successfully${NC}"
    else
        echo -e "${RED}❌ Some services failed to scale: ${failed_services[*]}${NC}"
        return 1
    fi
}

echo -e "${GREEN}⚖️  Starting scaling process...${NC}"
echo -e "Service: $SERVICE"
echo -e "Target Replicas: $REPLICAS"
echo -e "Environment: $ENVIRONMENT"
echo -e "Namespace: $NAMESPACE"
echo ""

# Show current status
echo -e "${GREEN}📊 Current status:${NC}"
if [ "$SERVICE" == "all" ]; then
    for service in "${!DEFAULT_REPLICAS[@]}"; do
        if kubectl get deployment $service -n $NAMESPACE &> /dev/null; then
            current=$(kubectl get deployment $service -n $NAMESPACE -o jsonpath='{.spec.replicas}')
            ready=$(kubectl get deployment $service -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            echo -e "  $service: $ready/$current"
        fi
    done
else
    if kubectl get deployment $SERVICE -n $NAMESPACE &> /dev/null; then
        current=$(kubectl get deployment $SERVICE -n $NAMESPACE -o jsonpath='{.spec.replicas}')
        ready=$(kubectl get deployment $SERVICE -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        echo -e "  $SERVICE: $ready/$current"
    fi
fi
echo ""

# Perform scaling
if [ "$SERVICE" == "all" ]; then
    scale_all_services $REPLICAS
else
    scale_service $SERVICE $REPLICAS
fi

echo -e "${GREEN}🎉 Scaling process completed!${NC}"

# Show final status
echo -e "${GREEN}📋 Final deployment status:${NC}"
kubectl get deployments -n $NAMESPACE
echo ""

# Show HPA status if exists
echo -e "${GREEN}📈 HPA Status:${NC}"
kubectl get hpa -n $NAMESPACE 2>/dev/null || echo "No HPA found"

echo -e "${YELLOW}💡 Tips:${NC}"
echo -e "  - Use '$0 status $ENVIRONMENT' to check current scaling status"
echo -e "  - Use '$0 all default $ENVIRONMENT' to reset to default replicas"
echo -e "  - HPA may override manual scaling for services with auto-scaling enabled"
