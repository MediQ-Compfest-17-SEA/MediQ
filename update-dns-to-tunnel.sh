#!/bin/bash

# Update DNS records to use Cloudflare proxy instead of direct IP

set -e

# Load Cloudflare credentials
CREDENTIALS_FILE="/etc/letsencrypt/cloudflare-secrets/cloudflare.ini"

echo "🔑 Reading Cloudflare API token..."
CF_API_TOKEN=$(sudo grep '^dns_cloudflare_api_token' "$CREDENTIALS_FILE" | sed 's/dns_cloudflare_api_token\s*=\s*//')

if [[ -z "$CF_API_TOKEN" ]]; then
    echo "❌ Error: Could not read Cloudflare API token"
    exit 1
fi

# Domain configuration
MAIN_DOMAIN="craftthingy.com"

declare -A SERVICES=(
    ["mediq-api-gateway"]="8601"
    ["mediq-user-service"]="8602" 
    ["mediq-ocr-service"]="8603"
    ["mediq-ocr-engine-service"]="8604"
    ["mediq-patient-queue-service"]="8605"
    ["mediq-institution-service"]="8606"
)

echo "🚀 Updating DNS records to use Cloudflare proxy..."

# Get Zone ID
echo "🔍 Getting Zone ID for $MAIN_DOMAIN..."
ZONE_ID_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${MAIN_DOMAIN}" \
      -H "Authorization: Bearer ${CF_API_TOKEN}" \
      -H "Content-Type: application/json")

ZONE_ID=$(echo "$ZONE_ID_RESPONSE" | jq -r '.result[0].id')

if [[ "$ZONE_ID" == "null" || -z "$ZONE_ID" ]]; then
    echo "❌ Error: Cannot find Zone ID for domain '$MAIN_DOMAIN'"
    exit 1
fi

echo "✅ Zone ID found: $ZONE_ID"

# Function to update DNS record to use proxy
update_dns_to_proxy() {
    local subdomain="$1"
    local full_domain="${subdomain}.${MAIN_DOMAIN}"
    
    echo ""
    echo "📍 Updating DNS record for $full_domain to use Cloudflare proxy..."
    
    # Get existing record ID
    RECORDS_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=A&name=${full_domain}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json")
    
    RECORD_ID=$(echo "$RECORDS_RESPONSE" | jq -r '.result[0].id')
    
    if [[ "$RECORD_ID" == "null" || -z "$RECORD_ID" ]]; then
        echo "❌ No existing A record found for $full_domain"
        return 1
    fi
    
    echo "📝 Found record ID: $RECORD_ID"
    
    # Update record to use proxy (proxied: true) and point to any IP (will be handled by tunnel)
    JSON_PAYLOAD=$(printf '{"type":"A","name":"%s","content":"192.0.2.1","ttl":1,"proxied":true}' "$subdomain")
    UPDATE_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "$JSON_PAYLOAD")
    
    SUCCESS=$(echo "$UPDATE_RESPONSE" | jq -r '.success')
    
    if [[ "$SUCCESS" == "true" ]]; then
        echo "✅ Updated $full_domain to use Cloudflare proxy"
    else
        echo "❌ Failed to update $full_domain"
        echo "$UPDATE_RESPONSE" | jq -r '.errors[].message' | while read -r line; do echo "- $line"; done
        return 1
    fi
}

# Update DNS records for all services
for service in "${!SERVICES[@]}"; do
    update_dns_to_proxy "$service"
    sleep 2
done

echo ""
echo "🎉 DNS update completed!"
echo ""
echo "⏳ Please wait 1-2 minutes for DNS propagation..."
echo ""
echo "🌐 Test URLs (should work after propagation):"
for service in "${!SERVICES[@]}"; do
    domain="${service}.${MAIN_DOMAIN}"
    echo "- https://${domain}/health"
done

echo ""
echo "🔍 To check DNS propagation:"
echo "nslookup mediq-api-gateway.craftthingy.com"
echo "dig mediq-api-gateway.craftthingy.com"
