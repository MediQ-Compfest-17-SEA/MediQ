#!/bin/bash

# Fix DNS records to point to CORRECT tunnel ID

set -e

# Load Cloudflare credentials
CREDENTIALS_FILE="/etc/letsencrypt/cloudflare-secrets/cloudflare.ini"

echo "🔑 Reading Cloudflare API token..."
CF_API_TOKEN=$(sudo grep '^dns_cloudflare_api_token' "$CREDENTIALS_FILE" | sed 's/dns_cloudflare_api_token\s*=\s*//')

if [[ -z "$CF_API_TOKEN" ]]; then
    echo "❌ Error: Could not read Cloudflare API token"
    exit 1
fi

# Domain configuration - CORRECT tunnel ID
MAIN_DOMAIN="craftthingy.com"
CORRECT_TUNNEL_ID="fa9c2200-79ee-4d0e-9429-d095b1a33581"
CORRECT_TUNNEL_DOMAIN="${CORRECT_TUNNEL_ID}.cfargotunnel.com"

declare -A SERVICES=(
    ["mediq-api-gateway"]="8601"
    ["mediq-user-service"]="8602" 
    ["mediq-ocr-service"]="8603"
    ["mediq-ocr-engine-service"]="8604"
    ["mediq-patient-queue-service"]="8605"
    ["mediq-institution-service"]="8606"
)

echo "🚀 Updating DNS records to point to CORRECT tunnel..."
echo "Correct tunnel domain: $CORRECT_TUNNEL_DOMAIN"

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

# Function to update to correct tunnel
update_to_correct_tunnel() {
    local subdomain="$1"
    local full_domain="${subdomain}.${MAIN_DOMAIN}"
    
    echo ""
    echo "📍 Updating DNS record for $full_domain to correct tunnel..."
    
    # Get existing record ID
    RECORDS_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${full_domain}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json")
    
    RECORD_ID=$(echo "$RECORDS_RESPONSE" | jq -r '.result[0].id')
    RECORD_TYPE=$(echo "$RECORDS_RESPONSE" | jq -r '.result[0].type')
    CURRENT_CONTENT=$(echo "$RECORDS_RESPONSE" | jq -r '.result[0].content')
    
    if [[ "$RECORD_ID" != "null" && -n "$RECORD_ID" ]]; then
        echo "📝 Found existing record: $RECORD_TYPE -> $CURRENT_CONTENT"
        
        # Update CNAME to point to correct tunnel
        echo "🔄 Updating CNAME to point to correct tunnel..."
        JSON_PAYLOAD=$(printf '{"type":"CNAME","name":"%s","content":"%s","ttl":1,"proxied":true}' "$subdomain" "$CORRECT_TUNNEL_DOMAIN")
        UPDATE_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
            -H "Authorization: Bearer ${CF_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "$JSON_PAYLOAD")
        
        SUCCESS=$(echo "$UPDATE_RESPONSE" | jq -r '.success')
        
        if [[ "$SUCCESS" == "true" ]]; then
            echo "✅ Updated $full_domain to point to correct tunnel: $CORRECT_TUNNEL_DOMAIN"
        else
            echo "❌ Failed to update $full_domain"
            echo "$UPDATE_RESPONSE" | jq -r '.errors[].message' | while read -r line; do echo "- $line"; done
            return 1
        fi
    else
        echo "❌ No existing record found for $full_domain"
        return 1
    fi
}

# Update DNS records for all services
for service in "${!SERVICES[@]}"; do
    update_to_correct_tunnel "$service"
    sleep 2
done

echo ""
echo "🎉 DNS records updated to point to CORRECT tunnel!"
echo ""
echo "Correct tunnel: $CORRECT_TUNNEL_DOMAIN"
echo ""
echo "⏳ Please wait 1-2 minutes for DNS propagation..."
echo ""
echo "🌐 Test URLs:"
for service in "${!SERVICES[@]}"; do
    domain="${service}.${MAIN_DOMAIN}"
    echo "- https://${domain}/health"
done
