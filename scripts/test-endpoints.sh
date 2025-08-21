#!/bin/bash

# Test all MediQ service endpoints

echo "🧪 Testing MediQ Backend Services..."
echo ""

# Function to test endpoint
test_endpoint() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}
    
    echo -n "Testing $name: "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    
    if [ "$response" = "$expected_status" ] || [ "$response" = "404" ] && [ "$expected_status" = "200" ]; then
        echo "✅ RUNNING (HTTP $response)"
    else
        echo "❌ FAILED (HTTP $response)"
    fi
}

echo "🔍 Local Services (Direct):"
test_endpoint "User Service" "http://localhost:8602"
test_endpoint "OCR Service" "http://localhost:8603" 
test_endpoint "OCR Engine" "http://localhost:8604"
test_endpoint "Patient Queue" "http://localhost:8605"
test_endpoint "Institution Service" "http://localhost:8606"
test_endpoint "API Gateway" "http://localhost:8601"

echo ""
echo "🌐 Health Endpoints:"
test_endpoint "Institution Health" "http://localhost:8606/health"
test_endpoint "OCR Engine Health" "http://localhost:8604/health/"

echo ""
echo "📋 Service Processes:"
ps aux | grep -E "(8602|8603|8604|8605|8606|8601)" | grep -v grep | while read line; do
    echo "  $line"
done

echo ""
echo "🔌 Port Status:"
for port in 8601 8602 8603 8604 8605 8606; do
    if lsof -i :$port > /dev/null 2>&1; then
        echo "  Port $port: ✅ LISTENING"
    else
        echo "  Port $port: ❌ NOT LISTENING"
    fi
done

echo ""
echo "📊 Infrastructure Services:"
echo "  MySQL: $(mysql -uroot -p'!@M@yIB3eF0rG1V2n!' -e 'SELECT 1' 2>/dev/null && echo '✅ CONNECTED' || echo '❌ DISCONNECTED')"
echo "  Redis: $(docker-compose -f docker-compose.infrastructure.yml ps redis | grep -q 'Up' && echo '✅ RUNNING' || echo '❌ STOPPED')"
echo "  RabbitMQ: $(docker-compose -f docker-compose.infrastructure.yml ps rabbitmq | grep -q 'Up' && echo '✅ RUNNING' || echo '❌ STOPPED')"
