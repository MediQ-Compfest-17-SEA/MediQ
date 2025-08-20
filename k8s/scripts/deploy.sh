#!/bin/bash

# MediQ Kubernetes Deployment Script
# Usage: ./deploy.sh [staging|production]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default environment
ENVIRONMENT=${1:-staging}
NAMESPACE="mediq-${ENVIRONMENT}"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(staging|production)$ ]]; then
    echo -e "${RED}Error: Environment must be 'staging' or 'production'${NC}"
    exit 1
fi

echo -e "${GREEN}🚀 Starting MediQ deployment to ${ENVIRONMENT} environment...${NC}"

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

# Function to apply manifests with retry
apply_with_retry() {
    local file=$1
    local retries=3
    local delay=5
    
    for ((i=1; i<=retries; i++)); do
        echo -e "${YELLOW}Applying $file (attempt $i/$retries)...${NC}"
        if kubectl apply -f "$file"; then
            echo -e "${GREEN}✅ Successfully applied $file${NC}"
            return 0
        else
            if [ $i -eq $retries ]; then
                echo -e "${RED}❌ Failed to apply $file after $retries attempts${NC}"
                return 1
            fi
            echo -e "${YELLOW}⏳ Retrying in ${delay}s...${NC}"
            sleep $delay
        fi
    done
}

# Function to wait for deployment to be ready
wait_for_deployment() {
    local deployment=$1
    local timeout=${2:-300}
    
    echo -e "${YELLOW}⏳ Waiting for deployment $deployment to be ready...${NC}"
    if kubectl rollout status deployment/$deployment -n $NAMESPACE --timeout=${timeout}s; then
        echo -e "${GREEN}✅ Deployment $deployment is ready${NC}"
    else
        echo -e "${RED}❌ Deployment $deployment failed to become ready${NC}"
        return 1
    fi
}

# Function to wait for statefulset to be ready
wait_for_statefulset() {
    local statefulset=$1
    local timeout=${2:-300}
    
    echo -e "${YELLOW}⏳ Waiting for statefulset $statefulset to be ready...${NC}"
    if kubectl rollout status statefulset/$statefulset -n $NAMESPACE --timeout=${timeout}s; then
        echo -e "${GREEN}✅ StatefulSet $statefulset is ready${NC}"
    else
        echo -e "${RED}❌ StatefulSet $statefulset failed to become ready${NC}"
        return 1
    fi
}

# Create namespace if it doesn't exist
echo -e "${GREEN}📁 Creating namespace: $NAMESPACE${NC}"
apply_with_retry "../namespaces/mediq-${ENVIRONMENT}.yaml"

# Apply RBAC and Security
echo -e "${GREEN}🔐 Applying RBAC and security policies...${NC}"
apply_with_retry "../rbac/service-accounts.yaml" -n $NAMESPACE
apply_with_retry "../network-policies/network-policies.yaml" -n $NAMESPACE

# Apply secrets (these should be updated with actual values in production)
echo -e "${GREEN}🔑 Applying secrets...${NC}"
echo -e "${YELLOW}⚠️  Warning: Update secret values in production!${NC}"
apply_with_retry "../secrets/database-secrets.yaml" -n $NAMESPACE
apply_with_retry "../secrets/jwt-secrets.yaml" -n $NAMESPACE

# Apply ConfigMaps
echo -e "${GREEN}⚙️  Applying configuration maps...${NC}"
apply_with_retry "../configmaps/api-gateway-config.yaml" -n $NAMESPACE
apply_with_retry "../configmaps/user-service-config.yaml" -n $NAMESPACE
apply_with_retry "../configmaps/ocr-service-config.yaml" -n $NAMESPACE
apply_with_retry "../configmaps/ocr-engine-service-config.yaml" -n $NAMESPACE
apply_with_retry "../configmaps/patient-queue-service-config.yaml" -n $NAMESPACE

# Deploy infrastructure services first
echo -e "${GREEN}🏗️  Deploying infrastructure services...${NC}"
apply_with_retry "../infrastructure/mysql-deployment.yaml" -n $NAMESPACE
apply_with_retry "../infrastructure/redis-deployment.yaml" -n $NAMESPACE
apply_with_retry "../infrastructure/rabbitmq-deployment.yaml" -n $NAMESPACE

# Wait for infrastructure to be ready
echo -e "${GREEN}⏳ Waiting for infrastructure services to be ready...${NC}"
wait_for_statefulset "mysql" 600 -n $NAMESPACE
wait_for_statefulset "redis" 300 -n $NAMESPACE
wait_for_statefulset "rabbitmq" 600 -n $NAMESPACE

# Deploy application services
echo -e "${GREEN}🚀 Deploying application services...${NC}"
apply_with_retry "../services/user-service-service.yaml" -n $NAMESPACE
apply_with_retry "../services/ocr-service-service.yaml" -n $NAMESPACE
apply_with_retry "../services/ocr-engine-service-service.yaml" -n $NAMESPACE
apply_with_retry "../services/patient-queue-service-service.yaml" -n $NAMESPACE
apply_with_retry "../services/api-gateway-service.yaml" -n $NAMESPACE

apply_with_retry "../deployments/user-service-deployment.yaml" -n $NAMESPACE
apply_with_retry "../deployments/ocr-engine-service-deployment.yaml" -n $NAMESPACE
apply_with_retry "../deployments/ocr-service-deployment.yaml" -n $NAMESPACE
apply_with_retry "../deployments/patient-queue-service-deployment.yaml" -n $NAMESPACE
apply_with_retry "../deployments/api-gateway-deployment.yaml" -n $NAMESPACE

# Wait for application services to be ready
echo -e "${GREEN}⏳ Waiting for application services to be ready...${NC}"
wait_for_deployment "user-service" -n $NAMESPACE
wait_for_deployment "ocr-engine-service" 600 -n $NAMESPACE
wait_for_deployment "ocr-service" -n $NAMESPACE
wait_for_deployment "patient-queue-service" -n $NAMESPACE
wait_for_deployment "api-gateway" -n $NAMESPACE

# Apply HPA for auto-scaling
echo -e "${GREEN}📈 Applying Horizontal Pod Autoscalers...${NC}"
apply_with_retry "../hpa/api-gateway-hpa.yaml" -n $NAMESPACE
apply_with_retry "../hpa/ocr-services-hpa.yaml" -n $NAMESPACE

# Deploy monitoring (only for production)
if [ "$ENVIRONMENT" == "production" ]; then
    echo -e "${GREEN}📊 Deploying monitoring stack...${NC}"
    apply_with_retry "../monitoring/prometheus.yaml" -n $NAMESPACE
    wait_for_deployment "prometheus" 600 -n $NAMESPACE
fi

# Apply ingress
echo -e "${GREEN}🌐 Applying ingress configuration...${NC}"
apply_with_retry "../infrastructure/ingress.yaml" -n $NAMESPACE

# Health check
echo -e "${GREEN}🏥 Performing health checks...${NC}"
sleep 30  # Give services time to fully start

# Check if all pods are running
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n $NAMESPACE

# Check services
echo -e "${YELLOW}Checking service status...${NC}"
kubectl get svc -n $NAMESPACE

# Check ingress
echo -e "${YELLOW}Checking ingress status...${NC}"
kubectl get ingress -n $NAMESPACE

echo -e "${GREEN}✅ MediQ deployment to ${ENVIRONMENT} completed successfully!${NC}"
echo -e "${GREEN}📋 Deployment Summary:${NC}"
echo -e "  - Namespace: ${NAMESPACE}"
echo -e "  - Environment: ${ENVIRONMENT}"
echo -e "  - Services deployed: API Gateway, User Service, OCR Service, OCR Engine Service, Patient Queue Service"
echo -e "  - Infrastructure: MySQL, Redis, RabbitMQ"
echo -e "  - Monitoring: Prometheus (production only)"
echo -e "  - Auto-scaling: Enabled"
echo -e "  - Network policies: Applied"

if [ "$ENVIRONMENT" == "production" ]; then
    echo -e "${YELLOW}⚠️  Production Deployment Notes:${NC}"
    echo -e "  - Update all secret values with production secrets"
    echo -e "  - Configure TLS certificates"
    echo -e "  - Set up proper backup procedures"
    echo -e "  - Configure monitoring alerts"
    echo -e "  - Review resource limits and requests"
fi

echo -e "${GREEN}🎉 Deployment completed! Your MediQ application is ready to use.${NC}"
