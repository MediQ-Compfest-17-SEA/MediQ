#!/bin/bash

# MediQ Kubernetes Health Check Script
# Usage: ./health-check.sh [staging|production]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parameters
ENVIRONMENT=${1:-staging}
NAMESPACE="mediq-${ENVIRONMENT}"

# Service endpoints for health checks
declare -A SERVICE_PORTS=(
    ["api-gateway"]="8601"
    ["user-service"]="8602"
    ["ocr-service"]="8603"
    ["ocr-engine-service"]="8604"
    ["patient-queue-service"]="8605"
)

declare -A INFRASTRUCTURE_PORTS=(
    ["mysql"]="3306"
    ["redis"]="6379"
    ["rabbitmq"]="5672"
)

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

# Function to check pod health
check_pod_health() {
    local deployment=$1
    local expected_replicas=$2
    
    echo -e "${BLUE}🔍 Checking $deployment pods...${NC}"
    
    # Get deployment info
    if ! kubectl get deployment $deployment -n $NAMESPACE &> /dev/null; then
        echo -e "${RED}❌ Deployment $deployment not found${NC}"
        return 1
    fi
    
    local desired=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    local ready=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local available=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
    
    echo -e "  Desired: $desired, Ready: $ready, Available: $available"
    
    # Check pod status
    local pods=$(kubectl get pods -l app=$deployment -n $NAMESPACE --no-headers 2>/dev/null)
    if [ -z "$pods" ]; then
        echo -e "${RED}❌ No pods found for $deployment${NC}"
        return 1
    fi
    
    local running_count=0
    local total_count=0
    
    while IFS= read -r pod_line; do
        local pod_name=$(echo $pod_line | awk '{print $1}')
        local status=$(echo $pod_line | awk '{print $3}')
        local ready=$(echo $pod_line | awk '{print $2}')
        
        total_count=$((total_count + 1))
        
        if [ "$status" == "Running" ] && [[ "$ready" =~ ^[0-9]+/[0-9]+$ ]]; then
            local ready_count=$(echo $ready | cut -d'/' -f1)
            local total_containers=$(echo $ready | cut -d'/' -f2)
            
            if [ "$ready_count" == "$total_containers" ]; then
                echo -e "  ✅ $pod_name: $status ($ready)"
                running_count=$((running_count + 1))
            else
                echo -e "  ⚠️  $pod_name: $status ($ready) - Not all containers ready"
            fi
        else
            echo -e "  ❌ $pod_name: $status ($ready)"
        fi
    done <<< "$pods"
    
    if [ "$running_count" -eq "$desired" ] && [ "$ready" -eq "$desired" ]; then
        echo -e "${GREEN}✅ $deployment is healthy ($running_count/$desired pods ready)${NC}"
        return 0
    else
        echo -e "${RED}❌ $deployment is unhealthy ($running_count/$desired pods ready)${NC}"
        return 1
    fi
}

# Function to check service health via HTTP
check_service_http_health() {
    local service=$1
    local port=$2
    local path=${3:-/health}
    
    echo -e "${BLUE}🔍 Checking $service HTTP health...${NC}"
    
    # Port forward to check health
    local local_port=$((8000 + RANDOM % 1000))
    kubectl port-forward service/$service $local_port:$port -n $NAMESPACE &>/dev/null &
    local port_forward_pid=$!
    
    sleep 2
    
    # Check health endpoint
    local health_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$local_port$path 2>/dev/null || echo "000")
    
    # Clean up port forward
    kill $port_forward_pid 2>/dev/null || true
    
    if [ "$health_status" == "200" ]; then
        echo -e "${GREEN}✅ $service HTTP health check passed${NC}"
        return 0
    else
        echo -e "${RED}❌ $service HTTP health check failed (Status: $health_status)${NC}"
        return 1
    fi
}

# Function to check infrastructure health
check_infrastructure_health() {
    local service=$1
    local port=$2
    
    echo -e "${BLUE}🔍 Checking $service infrastructure health...${NC}"
    
    # Check if service exists
    if ! kubectl get service $service-service -n $NAMESPACE &> /dev/null; then
        echo -e "${RED}❌ Service $service-service not found${NC}"
        return 1
    fi
    
    # Check if pods are running
    local pods=$(kubectl get pods -l app=$service -n $NAMESPACE --no-headers 2>/dev/null)
    if [ -z "$pods" ]; then
        echo -e "${RED}❌ No pods found for $service${NC}"
        return 1
    fi
    
    local healthy_pods=0
    while IFS= read -r pod_line; do
        local pod_name=$(echo $pod_line | awk '{print $1}')
        local status=$(echo $pod_line | awk '{print $3}')
        
        if [ "$status" == "Running" ]; then
            healthy_pods=$((healthy_pods + 1))
            echo -e "  ✅ $pod_name: $status"
        else
            echo -e "  ❌ $pod_name: $status"
        fi
    done <<< "$pods"
    
    if [ "$healthy_pods" -gt 0 ]; then
        echo -e "${GREEN}✅ $service is healthy ($healthy_pods pods running)${NC}"
        return 0
    else
        echo -e "${RED}❌ $service is unhealthy (no running pods)${NC}"
        return 1
    fi
}

# Function to check HPA status
check_hpa_status() {
    echo -e "${BLUE}📈 Checking HPA status...${NC}"
    
    local hpa_list=$(kubectl get hpa -n $NAMESPACE --no-headers 2>/dev/null)
    if [ -z "$hpa_list" ]; then
        echo -e "${YELLOW}⚠️  No HPA found${NC}"
        return 0
    fi
    
    while IFS= read -r hpa_line; do
        local hpa_name=$(echo $hpa_line | awk '{print $1}')
        local reference=$(echo $hpa_line | awk '{print $2}')
        local targets=$(echo $hpa_line | awk '{print $3}')
        local min_pods=$(echo $hpa_line | awk '{print $4}')
        local max_pods=$(echo $hpa_line | awk '{print $5}')
        local replicas=$(echo $hpa_line | awk '{print $6}')
        
        echo -e "  📊 $hpa_name: $replicas replicas (min: $min_pods, max: $max_pods)"
        echo -e "     Targets: $targets"
    done <<< "$hpa_list"
    
    echo -e "${GREEN}✅ HPA status checked${NC}"
}

# Function to check resource usage
check_resource_usage() {
    echo -e "${BLUE}💾 Checking resource usage...${NC}"
    
    # Check node resource usage
    echo -e "${YELLOW}Node Resource Usage:${NC}"
    kubectl top nodes 2>/dev/null || echo "Metrics not available"
    
    echo ""
    echo -e "${YELLOW}Pod Resource Usage:${NC}"
    kubectl top pods -n $NAMESPACE 2>/dev/null || echo "Metrics not available"
}

# Function to check persistent volumes
check_persistent_volumes() {
    echo -e "${BLUE}💽 Checking persistent volumes...${NC}"
    
    local pvcs=$(kubectl get pvc -n $NAMESPACE --no-headers 2>/dev/null)
    if [ -z "$pvcs" ]; then
        echo -e "${YELLOW}⚠️  No PVCs found${NC}"
        return 0
    fi
    
    while IFS= read -r pvc_line; do
        local pvc_name=$(echo $pvc_line | awk '{print $1}')
        local status=$(echo $pvc_line | awk '{print $2}')
        local volume=$(echo $pvc_line | awk '{print $3}')
        local capacity=$(echo $pvc_line | awk '{print $4}')
        
        if [ "$status" == "Bound" ]; then
            echo -e "  ✅ $pvc_name: $status ($capacity)"
        else
            echo -e "  ❌ $pvc_name: $status"
        fi
    done <<< "$pvcs"
}

# Function to check ingress
check_ingress() {
    echo -e "${BLUE}🌐 Checking ingress...${NC}"
    
    local ingress_list=$(kubectl get ingress -n $NAMESPACE --no-headers 2>/dev/null)
    if [ -z "$ingress_list" ]; then
        echo -e "${YELLOW}⚠️  No ingress found${NC}"
        return 0
    fi
    
    while IFS= read -r ingress_line; do
        local ingress_name=$(echo $ingress_line | awk '{print $1}')
        local hosts=$(echo $ingress_line | awk '{print $3}')
        local address=$(echo $ingress_line | awk '{print $4}')
        
        if [ ! -z "$address" ]; then
            echo -e "  ✅ $ingress_name: $hosts → $address"
        else
            echo -e "  ⚠️  $ingress_name: $hosts (no address assigned)"
        fi
    done <<< "$ingress_list"
}

# Main health check function
main() {
    echo -e "${GREEN}🏥 MediQ Health Check - $ENVIRONMENT Environment${NC}"
    echo -e "${BLUE}Namespace: $NAMESPACE${NC}"
    echo -e "${BLUE}Timestamp: $(date)${NC}"
    echo ""
    
    local overall_health=0
    
    # Check infrastructure services first
    echo -e "${GREEN}🏗️  Infrastructure Health Check${NC}"
    echo "================================================="
    for service in "${!INFRASTRUCTURE_PORTS[@]}"; do
        if ! check_infrastructure_health $service ${INFRASTRUCTURE_PORTS[$service]}; then
            overall_health=1
        fi
        echo ""
    done
    
    # Check application services
    echo -e "${GREEN}🚀 Application Services Health Check${NC}"
    echo "================================================="
    for service in "${!SERVICE_PORTS[@]}"; do
        if ! check_pod_health $service; then
            overall_health=1
        fi
        
        # HTTP health check (skip for now as it requires port forwarding)
        # check_service_http_health $service ${SERVICE_PORTS[$service]}
        echo ""
    done
    
    # Check HPA
    echo -e "${GREEN}📈 Auto-scaling Health Check${NC}"
    echo "================================================="
    check_hpa_status
    echo ""
    
    # Check persistent volumes
    echo -e "${GREEN}💽 Storage Health Check${NC}"
    echo "================================================="
    check_persistent_volumes
    echo ""
    
    # Check ingress
    echo -e "${GREEN}🌐 Ingress Health Check${NC}"
    echo "================================================="
    check_ingress
    echo ""
    
    # Check resource usage
    echo -e "${GREEN}💾 Resource Usage Check${NC}"
    echo "================================================="
    check_resource_usage
    echo ""
    
    # Summary
    echo -e "${GREEN}📋 Health Check Summary${NC}"
    echo "================================================="
    
    if [ $overall_health -eq 0 ]; then
        echo -e "${GREEN}✅ Overall Health: HEALTHY${NC}"
        echo -e "All critical services are running and healthy."
    else
        echo -e "${RED}❌ Overall Health: UNHEALTHY${NC}"
        echo -e "Some services have issues that need attention."
    fi
    
    echo ""
    echo -e "${YELLOW}📊 Quick Stats:${NC}"
    echo -e "Deployments: $(kubectl get deployments -n $NAMESPACE --no-headers 2>/dev/null | wc -l)"
    echo -e "Running Pods: $(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)"
    echo -e "Services: $(kubectl get services -n $NAMESPACE --no-headers 2>/dev/null | wc -l)"
    echo -e "PVCs: $(kubectl get pvc -n $NAMESPACE --no-headers 2>/dev/null | wc -l)"
    
    echo ""
    echo -e "${BLUE}💡 Commands for further investigation:${NC}"
    echo -e "  kubectl get pods -n $NAMESPACE"
    echo -e "  kubectl get services -n $NAMESPACE"
    echo -e "  kubectl logs -f deployment/api-gateway -n $NAMESPACE"
    echo -e "  kubectl describe hpa -n $NAMESPACE"
    
    return $overall_health
}

# Run main function
main "$@"
