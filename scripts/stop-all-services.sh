#!/bin/bash

# MediQ Backend - Stop All Services Script

echo "🛑 Stopping MediQ Backend Services..."

# Stop services by port
for port in 8601 8602 8603 8604 8605 8606; do
    echo "Stopping service on port $port..."
    pkill -f "port.*$port" || true
    pkill -f ":$port" || true
done

# Stop any remaining node processes for MediQ
pkill -f "MediQ-Backend" || true

# Stop Python flask processes
pkill -f "app.py" || true

sleep 2

echo "✅ All MediQ services stopped!"
