#!/bin/bash

# MediQ Integration Tests Runner
# This script sets up the test environment and runs comprehensive integration tests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.test.yml"
TIMEOUT=300 # 5 minutes timeout for services
PARALLEL_TESTS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --parallel)
      PARALLEL_TESTS=true
      shift
      ;;
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --parallel    Run tests in parallel (faster but may be less reliable)"
      echo "  --timeout N   Set timeout in seconds for service startup (default: 300)"
      echo "  --help        Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}🚀 Starting MediQ Integration Test Suite${NC}"
echo "==============================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ docker-compose not found. Please install docker-compose.${NC}"
    exit 1
fi

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up test environment...${NC}"
    docker-compose -f $COMPOSE_FILE down -v --remove-orphans > /dev/null 2>&1 || true
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

# Set up cleanup trap
trap cleanup EXIT INT TERM

# Start test infrastructure
echo -e "${BLUE}📦 Starting test infrastructure...${NC}"
docker-compose -f $COMPOSE_FILE up -d

# Wait for services to be healthy
echo -e "${YELLOW}⏳ Waiting for services to be ready (timeout: ${TIMEOUT}s)...${NC}"

services=("mysql-test" "redis-test" "rabbitmq-test" "ocr-engine-test")
for service in "${services[@]}"; do
    echo -n "  Checking $service... "
    
    # Wait for service to be healthy or running
    timeout $TIMEOUT bash -c "
        while true; do
            status=\$(docker-compose -f $COMPOSE_FILE ps -q $service | xargs docker inspect -f '{{.State.Health.Status}}' 2>/dev/null || echo 'none')
            if [[ \$status == 'healthy' ]]; then
                break
            elif [[ \$status == 'none' ]]; then
                # Service doesn't have healthcheck, check if it's running
                if docker-compose -f $COMPOSE_FILE ps $service | grep -q 'Up'; then
                    break
                fi
            fi
            sleep 2
        done
    " && echo -e "${GREEN}✅${NC}" || {
        echo -e "${RED}❌${NC}"
        echo -e "${RED}Failed to start $service within timeout${NC}"
        exit 1
    }
done

echo -e "${GREEN}✅ All services are ready${NC}"

# Verify connectivity
echo -e "${BLUE}🔍 Verifying service connectivity...${NC}"

# Test MySQL
echo -n "  MySQL connection... "
if docker exec $(docker-compose -f $COMPOSE_FILE ps -q mysql-test) mysql -u root -ptestpassword -e "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    exit 1
fi

# Test Redis
echo -n "  Redis connection... "
if docker exec $(docker-compose -f $COMPOSE_FILE ps -q redis-test) redis-cli ping > /dev/null 2>&1; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    exit 1
fi

# Test RabbitMQ
echo -n "  RabbitMQ connection... "
if docker exec $(docker-compose -f $COMPOSE_FILE ps -q rabbitmq-test) rabbitmq-diagnostics status > /dev/null 2>&1; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    exit 1
fi

# Set up test environment variables
export NODE_ENV=test
export TEST_DATABASE_URL="mysql://testuser:testpassword@localhost:3307/mediq_integration_test"
export REDIS_HOST=localhost
export REDIS_PORT=6380
export RABBITMQ_URL="amqp://testuser:testpassword@localhost:5673/test"
export OCR_API_URL=http://localhost:5001
export JWT_SECRET=test-jwt-secret
export JWT_REFRESH_SECRET=test-refresh-secret

echo -e "${GREEN}✅ Environment configured${NC}"

# Install dependencies if needed
if [[ ! -d "node_modules" ]]; then
    echo -e "${BLUE}📦 Installing dependencies...${NC}"
    npm ci
fi

# Run integration tests
echo -e "${BLUE}🧪 Running integration tests...${NC}"
echo "==============================================="

if [[ $PARALLEL_TESTS == true ]]; then
    echo -e "${YELLOW}⚡ Running tests in parallel mode${NC}"
    npm run test:integration -- --maxWorkers=4
else
    echo -e "${YELLOW}🔄 Running tests sequentially (safer)${NC}"
    npm run test:integration -- --runInBand
fi

test_exit_code=$?

if [[ $test_exit_code -eq 0 ]]; then
    echo -e "\n${GREEN}✅ All integration tests passed!${NC}"
    echo -e "${GREEN}🎉 Test suite completed successfully${NC}"
else
    echo -e "\n${RED}❌ Some integration tests failed${NC}"
    echo -e "${RED}💥 Test suite completed with failures${NC}"
fi

# Generate coverage report if tests passed
if [[ $test_exit_code -eq 0 ]]; then
    echo -e "${BLUE}📊 Generating coverage report...${NC}"
    npm run test:integration -- --coverage --coverageReporters=html --coverageReporters=text-summary
    
    if [[ -f "coverage/integration/lcov-report/index.html" ]]; then
        echo -e "${GREEN}📈 Coverage report generated: coverage/integration/lcov-report/index.html${NC}"
    fi
fi

# Show test summary
echo -e "\n${BLUE}📋 Test Summary${NC}"
echo "==============================================="
echo "Test Environment: Docker Compose"
echo "Database: MySQL (localhost:3307)"
echo "Cache: Redis (localhost:6380)"  
echo "Message Broker: RabbitMQ (localhost:5673)"
echo "OCR Engine: Flask API (localhost:5001)"
echo "Parallel Execution: $PARALLEL_TESTS"
echo "Exit Code: $test_exit_code"

exit $test_exit_code
