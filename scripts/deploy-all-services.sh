#!/bin/bash

# MediQ - Deploy All Services Script

set -e

echo "🚀 Starting MediQ Services Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we're connected to a cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Not connected to a Kubernetes cluster"
    exit 1
fi

print_status "Connected to cluster: $(kubectl config current-context)"

# Deploy shared infrastructure first
print_status "Deploying shared infrastructure..."
kubectl apply -f k8s/shared/infrastructure/
kubectl apply -f k8s/shared/monitoring/
kubectl apply -f k8s/namespaces/
kubectl apply -f k8s/rbac/
kubectl apply -f k8s/network-policies/

# Wait for infrastructure to be ready
print_status "Waiting for infrastructure to be ready..."
kubectl wait --for=condition=ready pod -l app=mysql -n mediq --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n mediq --timeout=300s
kubectl wait --for=condition=ready pod -l app=rabbitmq -n mediq --timeout=300s

# Deploy services
SERVICES=("user-service" "api-gateway" "ocr-service" "patient-queue-service" "ocr-engine-service")

for service in "${SERVICES[@]}"; do
    print_status "Deploying $service..."
    
    SERVICE_DIR=""
    case $service in
        "user-service")
            SERVICE_DIR="MediQ-Backend-User-Service"
            ;;
        "api-gateway")
            SERVICE_DIR="MediQ-Backend-API-Gateway"
            ;;
        "ocr-service")
            SERVICE_DIR="MediQ-Backend-OCR-Service"
            ;;
        "patient-queue-service")
            SERVICE_DIR="MediQ-Backend-Patient-Queue-Service"
            ;;
        "ocr-engine-service")
            SERVICE_DIR="MediQ-Backend-OCR-Engine-Service"
            ;;
    esac
    
    if [ -d "$SERVICE_DIR/k8s" ]; then
        kubectl apply -f "$SERVICE_DIR/k8s/"
        print_status "Deployed $service from $SERVICE_DIR"
    else
        print_warning "$SERVICE_DIR/k8s not found, skipping $service"
    fi
done

# Deploy ingress
print_status "Deploying ingress configuration..."
kubectl apply -f k8s/ingress.yaml

# Wait for deployments to be ready
print_status "Waiting for all deployments to be ready..."
for service in "${SERVICES[@]}"; do
    if kubectl get deployment "$service" -n mediq &> /dev/null; then
        print_status "Waiting for $service deployment..."
        kubectl rollout status deployment/"$service" -n mediq --timeout=300s
    fi
done

# Show deployment status
print_status "Deployment Status:"
kubectl get pods -n mediq
kubectl get services -n mediq
kubectl get ingress -n mediq

print_status "🎉 All services deployed successfully!"
print_status "API Gateway: http://api.mediq.local"
print_status "Monitoring: http://monitoring.mediq.local"
print_status "RabbitMQ Management: http://localhost:15672 (admin/admin)"

print_warning "Make sure to update your hosts file for local access:"
echo "127.0.0.1 api.mediq.local monitoring.mediq.local"
