#!/bin/bash

# Fix DNS records to be proxied through Cloudflare

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

echo "🚀 Updating DNS records to be proxied through Cloudflare..."

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

# Function to update DNS record to be proxied
update_dns_to_proxied() {
    local subdomain="$1"
    local full_domain="${subdomain}.${MAIN_DOMAIN}"
    
    echo ""
    echo "📍 Updating DNS record for $full_domain to be proxied..."
    
    # Get existing record ID
    RECORDS_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${full_domain}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json")
    
    RECORD_ID=$(echo "$RECORDS_RESPONSE" | jq -r '.result[0].id')
    RECORD_TYPE=$(echo "$RECORDS_RESPONSE" | jq -r '.result[0].type')
    CURRENT_PROXIED=$(echo "$RECORDS_RESPONSE" | jq -r '.result[0].proxied')
    
    if [[ "$RECORD_ID" == "null" || -z "$RECORD_ID" ]]; then
        echo "❌ No existing record found for $full_domain"
        return 1
    fi
    
    echo "📝 Found record ID: $RECORD_ID (type: $RECORD_TYPE, proxied: $CURRENT_PROXIED)"
    
    if [[ "$RECORD_TYPE" == "CNAME" ]]; then
        # Delete CNAME and create proxied A record pointing to dummy IP
        # Cloudflare will handle routing through tunnel when proxied
        echo "🗑️  Deleting CNAME record..."
        DELETE_RESPONSE=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
            -H "Authorization: Bearer ${CF_API_TOKEN}" \
            -H "Content-Type: application/json")
        
        DELETE_SUCCESS=$(echo "$DELETE_RESPONSE" | jq -r '.success')
        if [[ "$DELETE_SUCCESS" != "true" ]]; then
            echo "❌ Failed to delete CNAME record"
            return 1
        fi
        echo "✅ Deleted CNAME record"
        
        # Create proxied A record
        echo "📝 Creating proxied A record..."
        JSON_PAYLOAD=$(printf '{"type":"A","name":"%s","content":"192.0.2.1","ttl":1,"proxied":true}' "$subdomain")
        CREATE_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
            -H "Authorization: Bearer ${CF_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "$JSON_PAYLOAD")
        
        SUCCESS=$(echo "$CREATE_RESPONSE" | jq -r '.success')
        
        if [[ "$SUCCESS" == "true" ]]; then
            echo "✅ Created proxied A record for $full_domain"
        else
            echo "❌ Failed to create proxied A record for $full_domain"
            echo "$CREATE_RESPONSE" | jq -r '.errors[].message' | while read -r line; do echo "- $line"; done
            return 1
        fi
        
    elif [[ "$RECORD_TYPE" == "A" && "$CURRENT_PROXIED" == "false" ]]; then
        # Update existing A record to be proxied
        echo "📝 Updating A record to be proxied..."
        JSON_PAYLOAD=$(printf '{"type":"A","name":"%s","content":"192.0.2.1","ttl":1,"proxied":true}' "$subdomain")
        UPDATE_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
            -H "Authorization: Bearer ${CF_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "$JSON_PAYLOAD")
        
        SUCCESS=$(echo "$UPDATE_RESPONSE" | jq -r '.success')
        
        if [[ "$SUCCESS" == "true" ]]; then
            echo "✅ Updated A record to be proxied for $full_domain"
        else
            echo "❌ Failed to update A record for $full_domain"
            echo "$UPDATE_RESPONSE" | jq -r '.errors[].message' | while read -r line; do echo "- $line"; done
            return 1
        fi
        
    elif [[ "$RECORD_TYPE" == "A" && "$CURRENT_PROXIED" == "true" ]]; then
        echo "✅ Record already proxied for $full_domain"
    else
        echo "⚠️  Unknown record type or state for $full_domain"
    fi
}

# Update DNS records for all services
for service in "${!SERVICES[@]}"; do
    update_dns_to_proxied "$service"
    sleep 2
done

echo ""
echo "🎉 DNS proxy update completed!"
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
echo "curl -I https://mediq-api-gateway.craftthingy.com/health"
