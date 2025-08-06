#!/bin/bash

# Emergency script to get Outline Manager config when it's lost
echo "🆘 Emergency Outline Manager Config Recovery"
echo "============================================"

# Check if shadowbox is running
if ! docker ps | grep -q shadowbox; then
    echo "❌ Shadowbox not running!"
    exit 1
fi

echo "🔍 Searching for configuration..."

# Get external IP
EXTERNAL_IP=$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
echo "External IP: $EXTERNAL_IP"

# Method 1: Check all possible config locations
echo ""
echo "📁 Checking configuration files..."
docker exec shadowbox find /opt /root -name "*.json" -exec ls -la {} \; 2>/dev/null
docker exec shadowbox find /opt /root -name "*.crt" -exec ls -la {} \; 2>/dev/null

# Method 2: Look for API endpoint in all JSON files
echo ""
echo "🔍 Searching for API URLs in all JSON files..."
API_CONFIGS=$(docker exec shadowbox find /opt /root -name "*.json" -exec grep -l "apiUrl\|certSha256" {} \; 2>/dev/null)
if [ ! -z "$API_CONFIGS" ]; then
    echo "Found potential config files:"
    for config in $API_CONFIGS; do
        echo "File: $config"
        docker exec shadowbox cat "$config" 2>/dev/null | grep -o '{"apiUrl":"[^"]*","certSha256":"[^"]*"}' 2>/dev/null || echo "No direct match"
    done
fi

# Method 3: Try to reconstruct from Outline installation
echo ""
echo "🔧 Attempting reconstruction..."

# Find management port by checking what ports are open
MGMT_PORT=$(docker exec shadowbox netstat -tlnp 2>/dev/null | grep LISTEN | grep node | grep -o ':[0-9]*' | cut -d: -f2 | head -1)
if [ -z "$MGMT_PORT" ]; then
    # Fallback - look for common Outline management ports
    for port in 26666 50475 64304; do
        if docker exec shadowbox netstat -tlnp 2>/dev/null | grep ":$port"; then
            MGMT_PORT=$port
            break
        fi
    done
fi

echo "Management port candidate: $MGMT_PORT"

# Get certificate fingerprint
CERT_SHA=$(docker exec shadowbox find /opt /root -name "*.crt" -exec openssl x509 -in {} -noout -fingerprint -sha256 \; 2>/dev/null | cut -d= -f2 | tr -d ':' | head -1)
echo "Certificate SHA256: $CERT_SHA"

# Method 4: Brute force API key search
echo ""
echo "🔍 Searching for API keys..."
API_KEYS=$(docker exec shadowbox find /opt /root -name "*.json" -exec grep -o '[a-zA-Z0-9_-]\{22\}' {} \; 2>/dev/null | head -5)
echo "Potential API keys:"
echo "$API_KEYS"

# Method 5: Test common endpoints
if [ ! -z "$MGMT_PORT" ] && [ ! -z "$EXTERNAL_IP" ]; then
    echo ""
    echo "🧪 Testing endpoints..."
    
    for api_key in $API_KEYS; do
        TEST_URL="https://$EXTERNAL_IP:$MGMT_PORT/$api_key"
        echo "Testing: $TEST_URL"
        
        RESPONSE=$(curl -sk --max-time 3 "$TEST_URL/server" 2>/dev/null)
        if [ ! -z "$RESPONSE" ] && echo "$RESPONSE" | grep -q serverId; then
            echo "✅ WORKING API KEY FOUND!"
            echo ""
            echo "🎯 OUTLINE MANAGER CONFIGURATION:"
            echo "================================="
            
            if [ ! -z "$CERT_SHA" ]; then
                CONFIG="{\"apiUrl\":\"$TEST_URL\",\"certSha256\":\"$CERT_SHA\"}"
                echo "$CONFIG"
            else
                echo "API URL: $TEST_URL"
                echo "Certificate SHA256: [MANUAL_REQUIRED]"
            fi
            echo "================================="
            break
        fi
    done
fi

echo ""
echo "💡 If nothing worked, try:"
echo "- docker logs shadowbox | grep -i congratulations"
echo "- Reinstall: curl -sSL https://raw.githubusercontent.com/melanabeck01/myvpn-outline/main/install.sh | bash"