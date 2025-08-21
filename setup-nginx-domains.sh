#!/bin/bash

# Setup nginx reverse proxy dan SSL untuk semua MediQ microservices

# Services yang akan disetup
declare -A SERVICES=(
    ["mediq-api-gateway"]="8601"
    ["mediq-user-service"]="8602" 
    ["mediq-ocr-service"]="8603"
    ["mediq-ocr-engine-service"]="8604"
    ["mediq-patient-queue-service"]="8605"
    ["mediq-institution-service"]="8606"
)

# Domain utama
MAIN_DOMAIN="craftthingy.com"

echo "🚀 Setting up nginx reverse proxy for MediQ microservices..."
echo ""

# Fungsi untuk create nginx config
create_nginx_config() {
    local service="$1"
    local port="$2"
    local domain="${service}.${MAIN_DOMAIN}"
    
    echo "📁 Creating nginx config for $domain..."
    
    cat > "/tmp/${domain}.conf" << EOF
# Rate limiting
limit_req_zone \$binary_remote_addr zone=${service}_limit:10m rate=10r/s;

server {
    listen 80;
    server_name ${domain};
    
    # Rate limiting
    limit_req zone=${service}_limit burst=20 nodelay;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Logging
    access_log /var/log/nginx/${service}_access.log;
    error_log /var/log/nginx/${service}_error.log;
    
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
        
        # Proxy settings
        proxy_pass http://127.0.0.1:${port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
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
    }
}
EOF

    echo "✅ Created nginx config for $domain"
}

# Create nginx configs untuk semua services
for service in "${!SERVICES[@]}"; do
    port="${SERVICES[$service]}"
    create_nginx_config "$service" "$port"
done

echo ""
echo "📋 Created nginx configurations:"
for service in "${!SERVICES[@]}"; do
    domain="${service}.${MAIN_DOMAIN}"
    echo "- /tmp/${domain}.conf"
done

echo ""
echo "🔧 Next steps (run as root):"
echo "1. Copy configs to /etc/nginx/sites-available/"
echo "2. Enable sites with symlinks to /etc/nginx/sites-enabled/"
echo "3. Test nginx configuration"
echo "4. Reload nginx"
echo "5. Setup SSL certificates with certbot"

echo ""
echo "📝 Commands to run:"
echo "sudo cp /tmp/mediq-*.conf /etc/nginx/sites-available/"
echo "cd /etc/nginx/sites-enabled/"
for service in "${!SERVICES[@]}"; do
    domain="${service}.${MAIN_DOMAIN}"
    echo "sudo ln -sf ../sites-available/${domain}.conf ."
done
echo "sudo nginx -t"
echo "sudo systemctl reload nginx"
