#!/bin/bash

# MediQ Backend - Auto Deployment Script
# This script handles automatic deployment when GitHub repositories are updated

set -e

PROJECT_ROOT="/home/killerking/automated_project/compfest/MediQ"
LOG_FILE="$PROJECT_ROOT/logs/deployment.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to update a service
update_service() {
    local service_name=$1
    local directory=$2
    local port=$3
    
    log "🔄 Updating $service_name..."
    
    cd "$PROJECT_ROOT/$directory"
    
    # Pull latest changes
    git pull origin main || {
        log "❌ Failed to pull $service_name"
        return 1
    }
    
    # Install dependencies if package.json changed
    if git diff --name-only HEAD HEAD~1 | grep -q "package.json\|package-lock.json"; then
        log "📦 Installing dependencies for $service_name..."
        npm ci
    fi
    
    # Run Prisma migrations if schema changed
    if git diff --name-only HEAD HEAD~1 | grep -q "prisma/" && [ -d "prisma" ]; then
        log "🗄️ Running Prisma migrations for $service_name..."
        npx prisma generate
        npx prisma migrate deploy
    fi
    
    # Build service
    log "🏗️ Building $service_name..."
    npm run build || {
        log "❌ Build failed for $service_name"
        return 1
    }
    
    # Restart service with zero downtime
    log "🔄 Restarting $service_name..."
    pkill -f "port.*$port" || true
    
    if [[ "$service_name" == "OCR Engine Service" ]]; then
        nohup python3 app.py > "$PROJECT_ROOT/logs/${service_name,,}.log" 2>&1 &
    else
        nohup npm run start:prod > "$PROJECT_ROOT/logs/${service_name,,}.log" 2>&1 &
    fi
    
    # Health check
    sleep 10
    if curl -f "http://localhost:$port/health" > /dev/null 2>&1 || curl -f "http://localhost:$port/" > /dev/null 2>&1; then
        log "✅ $service_name restarted successfully"
    else
        log "⚠️  $service_name may have issues - check logs"
    fi
}

# Main deployment function
deploy_all() {
    log "🚀 Starting auto-deployment for MediQ Backend"
    
    # Update main repository
    cd "$PROJECT_ROOT"
    git pull origin main
    
    # Update individual services
    update_service "User Service" "MediQ-Backend-User-Service" 8602
    update_service "OCR Service" "MediQ-Backend-OCR-Service" 8603
    update_service "OCR Engine Service" "MediQ-Backend-OCR-Engine-Service" 8604
    update_service "Patient Queue Service" "MediQ-Backend-Patient-Queue-Service" 8605
    update_service "Institution Service" "MediQ-Backend-Institution-Service" 8606
    
    # API Gateway last (depends on other services)
    # update_service "API Gateway" "MediQ-Backend-API-Gateway" 8601
    
    log "🎉 Deployment completed!"
    
    # Send notification (optional)
    # curl -X POST "https://hooks.slack.com/..." -d "MediQ Backend deployed successfully"
}

# Handle different deployment scenarios
case "$1" in
    "webhook")
        # Called by GitHub webhook
        log "📡 Webhook triggered deployment"
        deploy_all
        ;;
    "manual")
        # Manual deployment
        log "👤 Manual deployment triggered"
        deploy_all
        ;;
    "service")
        # Deploy specific service
        if [ -z "$2" ]; then
            log "❌ Service name required for service deployment"
            exit 1
        fi
        log "🎯 Deploying specific service: $2"
        # Add service-specific deployment logic here
        ;;
    *)
        echo "Usage: $0 {webhook|manual|service <service-name>}"
        echo "  webhook - Triggered by GitHub webhook"
        echo "  manual  - Manual deployment"
        echo "  service - Deploy specific service"
        exit 1
        ;;
esac
