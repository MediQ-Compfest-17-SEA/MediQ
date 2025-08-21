#!/bin/bash

# Quick service exposure script
# This exposes MediQ services via kubectl port-forward for external access

echo "🌐 Exposing MediQ Services for External Access..."

# Kill existing port forwards
pkill -f "kubectl.*port-forward" || true

# Function to port forward with retry
expose_service() {
    local service=$1
    local local_port=$2
    local target_port=$3
    
    echo "Exposing $service: localhost:$local_port -> service:$target_port"
    kubectl port-forward service/$service $local_port:$target_port -n mediq > /dev/null 2>&1 &
    sleep 1
}

# Port forwards for external access
# expose_service "api-gateway" 8601 8601
expose_service "user-service" 8602 8602
# expose_service "ocr-service" 8603 8603  
expose_service "ocr-engine-service" 8604 8604
expose_service "patient-queue-service" 8605 8605
expose_service "institution-service" 8606 8606

echo ""
echo "✅ Services exposed! Access via:"
echo "- User Service: http://localhost:8602"
echo "- OCR Engine: http://localhost:8604" 
echo "- Patient Queue: http://localhost:8605"
echo "- Institution: http://localhost:8606"
echo ""
echo "🔗 For public access, setup Cloudflare tunnel:"
echo "cloudflared tunnel --config cloudflare/config.yml run"
