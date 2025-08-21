#!/bin/bash

# Fix nginx configuration for Cloudflare tunnel (no HTTPS redirect)

set -e

# Services configuration
declare -A SERVICES=(
    ["mediq-api-gateway"]="8601"
    ["mediq-user-service"]="8602" 
    ["mediq-ocr-service"]="8603"
    ["mediq-ocr-engine-service"]="8604"
    ["mediq-patient-queue-service"]="8605"
    ["mediq-institution-service"]="8606"
)

MAIN_DOMAIN="craftthingy.com"

echo "🚀 Fixing nginx configuration for Cloudflare tunnel..."

# Function to create tunnel-friendly nginx config
create_tunnel_friendly_config() {
    local service="$1"
    local port="$2"
    local domain="${service}.${MAIN_DOMAIN}"
    
    echo "📁 Creating tunnel-friendly config for $domain..."
    
    cat > "/tmp/${domain}.conf" << EOF
# Rate limiting zones
limit_req_zone \$binary_remote_addr zone=${service}_limit:10m rate=10r/s;

# Single server block for both HTTP and HTTPS (tunnel handles SSL termination)
server {
    listen 80;
    server_name ${domain};
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Rate limiting
    limit_req zone=${service}_limit burst=20 nodelay;
    
    # Logging
    access_log /var/log/nginx/${service}_access.log;
    error_log /var/log/nginx/${service}_error.log;
    
    # Main location block
    location / {
        # CORS headers for API
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type, X-Requested-With' always;
        
        # Handle preflight requests
        if (\$request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
            add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type, X-Requested-With';
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }
        
        # Proxy settings for Cloudflare tunnel
        proxy_pass http://127.0.0.1:${port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        
        # Important: Let Cloudflare handle HTTPS, don't force it here
        proxy_set_header X-Forwarded-Proto \$http_x_forwarded_proto;
        proxy_set_header X-Forwarded-Host \$host;
        
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        proxy_pass http://127.0.0.1:${port}/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$http_x_forwarded_proto;
    }
    
    # Metrics endpoint (protected)
    location /metrics {
        allow 127.0.0.1;
        allow 192.168.0.0/16;
        allow 10.0.0.0/8;
        deny all;
        
        proxy_pass http://127.0.0.1:${port}/metrics;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$http_x_forwarded_proto;
    }
    
    # API documentation (Swagger)
    location /api/docs {
        proxy_pass http://127.0.0.1:${port}/api/docs;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$http_x_forwarded_proto;
    }
}
EOF

    echo "✅ Created tunnel-friendly config for $domain"
}

# Create configs for all services
for service in "${!SERVICES[@]}"; do
    port="${SERVICES[$service]}"
    create_tunnel_friendly_config "$service" "$port"
done

echo ""
echo "🔧 Installing nginx configurations..."

# Install configurations
for service in "${!SERVICES[@]}"; do
    domain="${service}.${MAIN_DOMAIN}"
    echo "📁 Installing ${domain}.conf..."
    echo "!@34ALya" | sudo -S cp "/tmp/${domain}.conf" "/etc/nginx/sites-available/${domain}.conf"
done

# Test nginx configuration
echo "🧪 Testing nginx configuration..."
echo "!@34ALya" | sudo -S nginx -t

if [[ $? -eq 0 ]]; then
    echo "✅ Nginx configuration is valid"
    
    # Reload nginx
    echo "🔄 Reloading nginx..."
    echo "!@34ALya" | sudo -S systemctl reload nginx
    
    if [[ $? -eq 0 ]]; then
        echo "✅ Nginx reloaded successfully"
    else
        echo "❌ Failed to reload nginx"
        exit 1
    fi
else
    echo "❌ Nginx configuration test failed"
    exit 1
fi

echo ""
echo "🎉 Nginx configuration fixed for Cloudflare tunnel!"
echo ""
echo "🔧 Changes made:"
echo "- Removed HTTPS redirect (Cloudflare handles SSL termination)"
echo "- Updated proxy headers for tunnel compatibility"
echo "- Single server block listening on port 80"
echo ""
echo "🌐 Test URLs (should work now without redirect loop):"
for service in "${!SERVICES[@]}"; do
    domain="${service}.${MAIN_DOMAIN}"
    echo "- https://${domain}/health"
done
