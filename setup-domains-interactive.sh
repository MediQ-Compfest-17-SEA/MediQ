#!/bin/bash

# Setup domains untuk semua MediQ microservices menggunakan manajemen_domain
# Script otomatis dengan input yang sudah disiapkan

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

# IP public server
PUBLIC_IP=$(curl -s ifconfig.me)

echo "🚀 Setting up domains for MediQ microservices..."
echo "Domain utama: $MAIN_DOMAIN"
echo "IP Server: $PUBLIC_IP"
echo ""

# Fungsi untuk setup domain menggunakan manajemen_domain
setup_domain_interactive() {
    local subdomain="$1"
    local port="$2"
    local full_domain="${subdomain}.${MAIN_DOMAIN}"
    
    echo "📍 Setting up $full_domain..."
    
    # Create input file for manajemen_domain
    cat > /tmp/domain_input_${subdomain}.txt << EOF
2
${MAIN_DOMAIN}
${subdomain}
${PUBLIC_IP}
EOF

    # Run manajemen_domain with input
    sudo /usr/local/bin/manajemen_domain < /tmp/domain_input_${subdomain}.txt
    
    # Clean up input file
    rm -f /tmp/domain_input_${subdomain}.txt
    
    echo "✅ Completed setup for $full_domain"
    echo ""
}

# Setup domains untuk semua services
for service in "${!SERVICES[@]}"; do
    port="${SERVICES[$service]}"
    setup_domain_interactive "$service" "$port"
    
    # Wait a bit between requests to avoid rate limiting
    sleep 2
done

echo "🎉 Domain setup completed!"
echo ""
echo "📋 Summary:"
for service in "${!SERVICES[@]}"; do
    port="${SERVICES[$service]}"
    echo "- https://${service}.${MAIN_DOMAIN} -> localhost:${port}"
done

echo ""
echo "🔧 Next steps:"
echo "1. Update nginx configurations"
echo "2. Deploy to Kubernetes"
echo "3. Setup service mesh/ingress"
