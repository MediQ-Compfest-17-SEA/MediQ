#!/bin/bash

# MediQ Backend - Start All Services Script
# This script starts all MediQ microservices in the background

set -e

PROJECT_ROOT="/home/killerking/automated_project/compfest/MediQ"
LOG_DIR="$PROJECT_ROOT/logs"

# Create logs directory
mkdir -p "$LOG_DIR"

echo "🚀 Starting MediQ Backend Services..."

# Function to start a service
start_service() {
    local service_name=$1
    local port=$2
    local directory=$3
    
    echo "Starting $service_name on port $port..."
    
    cd "$PROJECT_ROOT/$directory"
    
    # Kill existing process if running
    pkill -f "port.*$port" || true
    
    # Start service in background
    if [[ "$service_name" == "OCR Engine Service" ]]; then
        # Python Flask service
        nohup python3 app.py > "$LOG_DIR/${service_name,,}.log" 2>&1 &
    else
        # Node.js NestJS services
        nohup npm run start:dev > "$LOG_DIR/${service_name,,}.log" 2>&1 &
    fi
    
    echo "$service_name started with PID $!"
    sleep 2
}

# Start each service
start_service "User Service" 8602 "MediQ-Backend-User-Service"
start_service "OCR Service" 8603 "MediQ-Backend-OCR-Service" 
start_service "OCR Engine Service" 8604 "MediQ-Backend-OCR-Engine-Service"
start_service "Patient Queue Service" 8605 "MediQ-Backend-Patient-Queue-Service"
start_service "Institution Service" 8606 "MediQ-Backend-Institution-Service"

# Start API Gateway last (depends on other services)
sleep 5
# Note: API Gateway has compilation errors, starting others first
# start_service "API Gateway" 8601 "MediQ-Backend-API-Gateway"

echo ""
echo "✅ MediQ Services Started!"
echo ""
echo "📊 Service Status:"
echo "- User Service:          http://localhost:8602/health"
echo "- OCR Service:           http://localhost:8603/health" 
echo "- OCR Engine Service:    http://localhost:8604/health"
echo "- Patient Queue Service: http://localhost:8605/health"
echo "- Institution Service:   http://localhost:8606/health"
echo ""
echo "📝 Logs are available in: $LOG_DIR/"
echo ""
echo "🌐 Public URLs (via nginx):"
echo "- User Service:          http://mediq-user-service.craftthingy.com"
echo "- OCR Service:           http://mediq-ocr-service.craftthingy.com"
echo "- OCR Engine Service:    http://mediq-ocr-engine-service.craftthingy.com"
echo "- Patient Queue Service: http://mediq-patient-queue-service.craftthingy.com"
echo "- Institution Service:   http://mediq-institution-service.craftthingy.com"

echo ""
echo "🔧 To stop all services, run: ./scripts/stop-all-services.sh"
