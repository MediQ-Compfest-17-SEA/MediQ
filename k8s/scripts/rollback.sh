#!/bin/bash

# MediQ Kubernetes Rollback Script
# Usage: ./rollback.sh [service] [staging|production] [revision]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parameters
SERVICE=${1}
ENVIRONMENT=${2:-staging}
REVISION=${3}
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

# Function to show usage
show_usage() {
    echo "Usage: $0 [service] [environment] [revision]"
    echo ""
    echo "Parameters:"
    echo "  service     - Service to rollback (${SERVICES[*]})"
    echo "  environment - Target environment (staging|production) [default: staging]"
    echo "  revision    - Revision number to rollback to (optional)"
    echo ""
    echo "Examples:"
    echo "  $0 api-gateway staging"
    echo "  $0 user-service production 3"
    echo "  $0 all staging"
    exit 1
}

# Validate parameters
if [ -z "$SERVICE" ]; then
    echo -e "${RED}Error: Service parameter is required${NC}"
    show_usage
fi

# Validate service
if [[ ! " ${SERVICES[@]} " =~ " ${SERVICE} " ]]; then
    echo -e "${RED}Error: Invalid service. Available services: ${SERVICES[*]}${NC}"
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

# Function to rollback a service
rollback_service() {
    local service=$1
    local revision_param=""
    
    if [ ! -z "$REVISION" ]; then
        revision_param="--to-revision=$REVISION"
    fi
    
    echo -e "${YELLOW}🔄 Rolling back $service in $ENVIRONMENT environment...${NC}"
    
    # Check if deployment exists
    if ! kubectl get deployment $service -n $NAMESPACE &> /dev/null; then
        echo -e "${RED}❌ Deployment $service not found in namespace $NAMESPACE${NC}"
        return 1
    fi
    
    # Show rollout history
    echo -e "${YELLOW}📜 Rollout history for $service:${NC}"
    kubectl rollout history deployment/$service -n $NAMESPACE
    
    # Confirm rollback
    if [ -z "$REVISION" ]; then
        echo -e "${YELLOW}⚠️  Are you sure you want to rollback $service to the previous revision? (y/N)${NC}"
        read -r response
        if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo -e "${YELLOW}Rollback cancelled for $service${NC}"
            return 0
        fi
    else
        echo -e "${YELLOW}⚠️  Are you sure you want to rollback $service to revision $REVISION? (y/N)${NC}"
        read -r response
        if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo -e "${YELLOW}Rollback cancelled for $service${NC}"
            return 0
        fi
    fi
    
    # Perform rollback
    if kubectl rollout undo deployment/$service -n $NAMESPACE $revision_param; then
        echo -e "${GREEN}✅ Rollback initiated for $service${NC}"
        
        # Wait for rollback to complete
        echo -e "${YELLOW}⏳ Waiting for rollback to complete...${NC}"
        if kubectl rollout status deployment/$service -n $NAMESPACE --timeout=300s; then
            echo -e "${GREEN}✅ Rollback completed successfully for $service${NC}"
            
            # Show new status
            kubectl get pods -l app=$service -n $NAMESPACE
        else
            echo -e "${RED}❌ Rollback failed for $service${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Failed to initiate rollback for $service${NC}"
        return 1
    fi
}

# Function to rollback all services
rollback_all_services() {
    local services_list=("api-gateway" "user-service" "ocr-service" "ocr-engine-service" "patient-queue-service")
    local failed_services=()
    
    echo -e "${YELLOW}⚠️  Are you sure you want to rollback ALL services in $ENVIRONMENT? (y/N)${NC}"
    read -r response
    if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo -e "${YELLOW}Rollback cancelled${NC}"
        return 0
    fi
    
    echo -e "${GREEN}🔄 Rolling back all services...${NC}"
    
    # Rollback in reverse order (API Gateway last)
    for ((i=${#services_list[@]}-1; i>=0; i--)); do
        local service=${services_list[i]}
        echo -e "${GREEN}Processing $service...${NC}"
        
        if ! rollback_service $service; then
            failed_services+=($service)
        fi
        
        # Add delay between services
        sleep 10
    done
    
    # Report results
    if [ ${#failed_services[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ All services rolled back successfully${NC}"
    else
        echo -e "${RED}❌ Some services failed to rollback: ${failed_services[*]}${NC}"
        return 1
    fi
}

echo -e "${GREEN}🔄 Starting rollback process...${NC}"
echo -e "Service: $SERVICE"
echo -e "Environment: $ENVIRONMENT"
echo -e "Namespace: $NAMESPACE"
if [ ! -z "$REVISION" ]; then
    echo -e "Target Revision: $REVISION"
fi
echo ""

# Perform rollback
if [ "$SERVICE" == "all" ]; then
    rollback_all_services
else
    rollback_service $SERVICE
fi

echo -e "${GREEN}🎉 Rollback process completed!${NC}"

# Show final status
echo -e "${GREEN}📋 Current deployment status:${NC}"
kubectl get deployments -n $NAMESPACE
echo ""
kubectl get pods -n $NAMESPACE

echo -e "${YELLOW}💡 Tip: Use 'kubectl rollout history deployment/<service> -n $NAMESPACE' to view rollout history${NC}"
