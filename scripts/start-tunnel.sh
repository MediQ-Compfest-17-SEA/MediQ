#!/bin/bash

# Start Cloudflare tunnel for MediQ services
# This makes services available via craftthingy.com subdomains

echo "🚇 Starting Cloudflare Tunnel for MediQ Backend..."

# Check if cloudflared is available
if ! command -v cloudflared &> /dev/null; then
    echo "❌ cloudflared not found. Please install it first."
    exit 1
fi

# Start tunnel with quick setup
echo "🔧 Starting tunnel for localhost services..."

# For now, use quick tunnel to test connectivity
# This will give us temporary URLs for testing

cloudflared tunnel --url http://localhost:8602 &
TUNNEL_PID_8602=$!

cloudflared tunnel --url http://localhost:8604 &
TUNNEL_PID_8604=$!

cloudflared tunnel --url http://localhost:8605 &
TUNNEL_PID_8605=$!

cloudflared tunnel --url http://localhost:8606 &
TUNNEL_PID_8606=$!

echo ""
echo "✅ Tunnels started!"
echo "📝 PIDs: $TUNNEL_PID_8602, $TUNNEL_PID_8604, $TUNNEL_PID_8605, $TUNNEL_PID_8606"
echo ""
echo "🌐 Check output above for temporary tunnel URLs"
echo ""
echo "🛑 To stop all tunnels: pkill -f cloudflared"

# Keep script running
wait
