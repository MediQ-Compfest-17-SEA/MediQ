#!/bin/bash

# Batch setup domains for MediQ microservices
# This script directly calls Cloudflare API without interaction

set -e

# Load Cloudflare credentials
CREDENTIALS_FILE="/etc/letsencrypt/cloudflare-secrets/cloudflare.ini"

if [[ ! -f "$CREDENTIALS_FILE" ]]; then
    echo "❌ Error: Cloudflare credentials file not found"
    exit 1
fi

# Read API token (requires sudo)
echo "🔑 Reading Cloudflare API token..."
CF_API_TOKEN=$(sudo grep '^dns_cloudflare_api_token' "$CREDENTIALS_FILE" | sed 's/dns_cloudflare_api_token\s*=\s*//')

if [[ -z "$CF_API_TOKEN" ]]; then
    echo "❌ Error: Could not read Cloudflare API token"
    exit 1
fi

# Domain configuration
MAIN_DOMAIN="craftthingy.com"
PUBLIC_IP=$(curl -s ifconfig.me)

declare -A SERVICES=(
    ["mediq-api-gateway"]="8601"
    ["mediq-user-service"]="8602" 
    ["mediq-ocr-service"]="8603"
    ["mediq-ocr-engine-service"]="8604"
    ["mediq-patient-queue-service"]="8605"
    ["mediq-institution-service"]="8606"
)

echo "🚀 Setting up domains for MediQ microservices..."
echo "Domain: $MAIN_DOMAIN"
echo "IP: $PUBLIC_IP"
echo ""

# Get Zone ID
echo "🔍 Getting Zone ID for $MAIN_DOMAIN..."
ZONE_ID_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${MAIN_DOMAIN}" \
      -H "Authorization: Bearer ${CF_API_TOKEN}" \
      -H "Content-Type: application/json")

ZONE_ID=$(echo "$ZONE_ID_RESPONSE" | jq -r '.result[0].id')

if [[ "$ZONE_ID" == "null" || -z "$ZONE_ID" ]]; then
    echo "❌ Error: Cannot find Zone ID for domain '$MAIN_DOMAIN'"
    echo "Response: $ZONE_ID_RESPONSE"
    exit 1
fi

echo "✅ Zone ID found: $ZONE_ID"

# Function to setup domain and SSL
setup_domain_and_ssl() {
    local subdomain="$1"
    local port="$2"
    local full_domain="${subdomain}.${MAIN_DOMAIN}"
    
    echo ""
    echo "📍 Setting up $full_domain..."
    
    # Create DNS A Record
    echo "🌐 Creating DNS A record for $full_domain -> $PUBLIC_IP..."
    JSON_PAYLOAD=$(printf '{"type":"A","name":"%s","content":"%s","ttl":1,"proxied":false}' "$subdomain" "$PUBLIC_IP")
    RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "$JSON_PAYLOAD")
    
    SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
    
    if [[ "$SUCCESS" == "true" ]]; then
        echo "✅ DNS A record created for $full_domain"
    else
        if echo "$RESPONSE" | grep -q "record already exists"; then
            echo "ℹ️  DNS record already exists for $full_domain"
        else
            echo "❌ Failed to create DNS record for $full_domain"
            echo "$RESPONSE" | jq -r '.errors[].message' | while read -r line; do echo "- $line"; done
            return 1
        fi
    fi
    
    # Create SSL certificate
    echo "🔒 Creating SSL certificate for $full_domain..."
    sudo certbot certonly \
        --dns-cloudflare \
        --dns-cloudflare-credentials "$CREDENTIALS_FILE" \
        --dns-cloudflare-propagation-seconds 30 \
        -d "$full_domain" \
        --non-interactive \
        --agree-tos \
        --keep-until-expiring \
        --email admin@craftthingy.com
        
    if [[ $? -eq 0 ]]; then
        echo "✅ SSL certificate created for $full_domain"
    else
        echo "❌ Failed to create SSL certificate for $full_domain"
        return 1
    fi
    
    echo "✅ Completed setup for $full_domain"
}

# Setup domains for all services
for service in "${!SERVICES[@]}"; do
    port="${SERVICES[$service]}"
    setup_domain_and_ssl "$service" "$port"
    
    # Wait between requests to avoid rate limiting
    sleep 5
done

echo ""
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
echo "2. Test domain access"
echo "3. Deploy services to production"
