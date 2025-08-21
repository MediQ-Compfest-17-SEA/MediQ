#!/bin/bash

# Setup domains untuk semua MediQ microservices
# Script otomatis menggunakan manajemen_domain

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

# Fungsi untuk setup domain via API Cloudflare
setup_domain_api() {
    local subdomain="$1"
    local port="$2"
    local full_domain="${subdomain}.${MAIN_DOMAIN}"
    
    echo "📍 Setting up $full_domain..."
    
    # Load Cloudflare API Token
    CREDENTIALS_FILE="/etc/letsencrypt/cloudflare-secrets/cloudflare.ini"
    CF_API_TOKEN=$(grep '^dns_cloudflare_api_token' "$CREDENTIALS_FILE" | sed 's/dns_cloudflare_api_token\s*=\s*//')
    
    # Get Zone ID
    ZONE_ID_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${MAIN_DOMAIN}" \
          -H "Authorization: Bearer ${CF_API_TOKEN}" \
          -H "Content-Type: application/json")
    
    ZONE_ID=$(echo "$ZONE_ID_RESPONSE" | jq -r '.result[0].id')
    
    if [[ "$ZONE_ID" == "null" || -z "$ZONE_ID" ]]; then
        echo "❌ Error: Cannot find Zone ID for domain '$MAIN_DOMAIN'"
        return 1
    fi
    
    # Create DNS A Record
    JSON_PAYLOAD=$(printf '{"type":"A","name":"%s","content":"%s","ttl":1,"proxied":false}' "$subdomain" "$PUBLIC_IP")
    RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "$JSON_PAYLOAD")
    
    SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
    
    if [[ "$SUCCESS" == "true" ]]; then
        echo "✅ DNS A record created for $full_domain"
        
        # Create SSL certificate
        echo "🔒 Creating SSL certificate for $full_domain..."
        sudo certbot certonly \
            --dns-cloudflare \
            --dns-cloudflare-credentials /etc/letsencrypt/cloudflare-secrets/cloudflare.ini \
            --dns-cloudflare-propagation-seconds 30 \
            -d ${full_domain} \
            --non-interactive \
            --agree-tos \
            --keep-until-expiring \
            --email admin@craftthingy.com \
            --force-renewal
            
        if [[ $? -eq 0 ]]; then
            echo "✅ SSL certificate created for $full_domain"
        else
            echo "❌ Failed to create SSL certificate for $full_domain"
        fi
        
    else
        echo "❌ Failed to create DNS record for $full_domain"
        echo "$RESPONSE" | jq -r '.errors[].message' | while read -r line; do echo "- $line"; done
        
        # Check if record already exists
        if echo "$RESPONSE" | grep -q "record already exists"; then
            echo "ℹ️  DNS record already exists, creating SSL only..."
            
            # Create SSL certificate
            echo "🔒 Creating SSL certificate for $full_domain..."
            sudo certbot certonly \
                --dns-cloudflare \
                --dns-cloudflare-credentials /etc/letsencrypt/cloudflare-secrets/cloudflare.ini \
                --dns-cloudflare-propagation-seconds 30 \
                -d ${full_domain} \
                --non-interactive \
                --agree-tos \
                --keep-until-expiring \
                --email admin@craftthingy.com \
                --force-renewal
                
            if [[ $? -eq 0 ]]; then
                echo "✅ SSL certificate created for $full_domain"
            else
                echo "❌ Failed to create SSL certificate for $full_domain"
            fi
        fi
    fi
    
    echo ""
}

# Setup domains untuk semua services
for service in "${!SERVICES[@]}"; do
    port="${SERVICES[$service]}"
    setup_domain_api "$service" "$port"
done

echo "🎉 Domain setup completed!"
echo ""
echo "📋 Summary:"
for service in "${!SERVICES[@]}"; do
    port="${SERVICES[$service]}"
    echo "- https://${service}.${MAIN_DOMAIN} -> localhost:${port}"
done
