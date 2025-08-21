#!/bin/bash

# Fix DNS records to be PROXIED CNAME pointing to tunnel (correct way!)

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
TUNNEL_ID="5bbbbaf9-ec0c-460e-a929-289245632174"
TUNNEL_DOMAIN="${TUNNEL_ID}.cfargotunnel.com"

declare -A SERVICES=(
    ["mediq-api-gateway"]="8601"
    ["mediq-user-service"]="8602" 
    ["mediq-ocr-service"]="8603"
    ["mediq-ocr-engine-service"]="8604"
    ["mediq-patient-queue-service"]="8605"
    ["mediq-institution-service"]="8606"
)

echo "🚀 Creating PROXIED CNAME records pointing to tunnel..."
echo "Tunnel domain: $TUNNEL_DOMAIN"

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

# Function to create correct PROXIED CNAME
fix_dns_to_proxied_cname() {
    local subdomain="$1"
    local full_domain="${subdomain}.${MAIN_DOMAIN}"
    
    echo ""
    echo "📍 Fixing DNS record for $full_domain..."
    
    # Get existing record ID
    RECORDS_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${full_domain}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json")
    
    RECORD_ID=$(echo "$RECORDS_RESPONSE" | jq -r '.result[0].id')
    RECORD_TYPE=$(echo "$RECORDS_RESPONSE" | jq -r '.result[0].type')
    CURRENT_PROXIED=$(echo "$RECORDS_RESPONSE" | jq -r '.result[0].proxied')
    
    if [[ "$RECORD_ID" != "null" && -n "$RECORD_ID" ]]; then
        echo "📝 Found existing record ID: $RECORD_ID (type: $RECORD_TYPE, proxied: $CURRENT_PROXIED)"
        
        # Delete existing record
        echo "🗑️  Deleting existing record..."
        DELETE_RESPONSE=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
            -H "Authorization: Bearer ${CF_API_TOKEN}" \
            -H "Content-Type: application/json")
        
        DELETE_SUCCESS=$(echo "$DELETE_RESPONSE" | jq -r '.success')
        if [[ "$DELETE_SUCCESS" != "true" ]]; then
            echo "❌ Failed to delete existing record"
            return 1
        fi
        echo "✅ Deleted existing record"
    fi
    
    # Create PROXIED CNAME record pointing to tunnel
    echo "📝 Creating PROXIED CNAME record pointing to $TUNNEL_DOMAIN..."
    JSON_PAYLOAD=$(printf '{"type":"CNAME","name":"%s","content":"%s","ttl":1,"proxied":true}' "$subdomain" "$TUNNEL_DOMAIN")
    CREATE_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "$JSON_PAYLOAD")
    
    SUCCESS=$(echo "$CREATE_RESPONSE" | jq -r '.success')
    
    if [[ "$SUCCESS" == "true" ]]; then
        echo "✅ Created PROXIED CNAME record for $full_domain -> $TUNNEL_DOMAIN"
    else
        echo "❌ Failed to create PROXIED CNAME record for $full_domain"
        echo "$CREATE_RESPONSE" | jq -r '.errors[].message' | while read -r line; do echo "- $line"; done
        return 1
    fi
}

# Fix DNS records for all services
for service in "${!SERVICES[@]}"; do
    fix_dns_to_proxied_cname "$service"
    sleep 2
done

echo ""
echo "🎉 DNS records fixed! All domains now have PROXIED CNAME pointing to tunnel!"
echo ""
echo "⏳ Please wait 1-2 minutes for DNS propagation..."
echo ""
echo "🌐 Test URLs (should work after propagation):"
for service in "${!SERVICES[@]}"; do
    domain="${service}.${MAIN_DOMAIN}"
    echo "- https://${domain}/health"
done

echo ""
echo "🔍 To verify DNS setup:"
echo "nslookup mediq-api-gateway.craftthingy.com"
echo "dig mediq-api-gateway.craftthingy.com"
echo ""
echo "Should show:"
echo "- CNAME pointing to $TUNNEL_DOMAIN"
echo "- Resolved through Cloudflare proxy IPs"
