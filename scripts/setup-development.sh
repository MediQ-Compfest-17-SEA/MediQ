#!/bin/bash

# MediQ - Development Environment Setup Script

set -e

echo "🚀 Setting up MediQ Development Environment..."

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

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    exit 1
fi

if ! docker info &> /dev/null; then
    print_error "Docker daemon is not running"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed"
    exit 1
fi

print_status "Docker and Docker Compose are ready"

# Start infrastructure services
print_status "Starting shared infrastructure services..."
docker-compose -f docker-compose.infrastructure.yml up -d

# Wait for services to be ready
print_status "Waiting for infrastructure services to be ready..."
sleep 30

# Check service health
print_status "Checking service health..."

# MySQL
if docker-compose -f docker-compose.infrastructure.yml exec -T mysql mysqladmin ping -h localhost &> /dev/null; then
    print_status "✅ MySQL is ready"
else
    print_warning "❌ MySQL is not ready yet"
fi

# Redis
if docker-compose -f docker-compose.infrastructure.yml exec -T redis redis-cli ping &> /dev/null; then
    print_status "✅ Redis is ready"
else
    print_warning "❌ Redis is not ready yet"
fi

# RabbitMQ
if docker-compose -f docker-compose.infrastructure.yml exec -T rabbitmq rabbitmq-diagnostics -q ping &> /dev/null; then
    print_status "✅ RabbitMQ is ready"
else
    print_warning "❌ RabbitMQ is not ready yet"
fi

# Display service information
print_status "Infrastructure Services Status:"
docker-compose -f docker-compose.infrastructure.yml ps

print_status "🎉 Development environment is ready!"
print_status ""
print_status "Service Endpoints:"
print_status "  MySQL:    localhost:3306 (user/password)"
print_status "  Redis:    localhost:6379"
print_status "  RabbitMQ: localhost:5672 (guest/guest)"
print_status "  RabbitMQ Management: http://localhost:15672 (guest/guest)"
print_status "  Prometheus: http://localhost:9090"
print_status "  Grafana: http://localhost:3000 (admin/admin)"
print_status ""
print_status "Next steps:"
print_status "1. Navigate to each service directory"
print_status "2. Run 'docker-compose up -d' to start individual services"
print_status "3. Or run 'npm run dev' for development mode"
print_status ""
print_status "To stop infrastructure:"
print_status "docker-compose -f docker-compose.infrastructure.yml down"
