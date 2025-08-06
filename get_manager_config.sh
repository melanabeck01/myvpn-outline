#!/bin/bash

# Get Outline Manager Configuration Script
# Extracts the JSON configuration needed for Outline Manager

echo "📋 Getting Outline Manager Configuration..."
echo "=========================================="

# Check if Docker is running
if ! systemctl is-active --quiet docker; then
    echo "⚠️  Starting Docker..."
    systemctl start docker
    sleep 3
fi

# Check if Shadowbox container exists and is running
if ! docker ps | grep -q shadowbox; then
    echo "⚠️  Shadowbox not running, trying to start..."
    docker start shadowbox 2>/dev/null || {
        echo "❌ Shadowbox container not found"
        echo "💡 Try running the install script first:"
        echo "curl -sSL https://raw.githubusercontent.com/melanabeck01/myvpn-outline/main/install.sh | bash"
        exit 1
    }
    sleep 3
fi

echo "🔍 Searching for Outline Manager configuration..."
echo ""

# Method 1: Extract from recent logs (most reliable for fresh installs)
echo "🔍 Method 1: From installation logs"
echo "-----------------------------------"
CONFIG=$(docker logs shadowbox 2>/dev/null | grep -o '{"apiUrl":"https://[^"]*","certSha256":"[^"]*"}' | tail -1)
if [ ! -z "$CONFIG" ]; then
    echo "✅ Configuration found in logs:"
    echo ""
    echo "🎯 COPY THIS JSON TO OUTLINE MANAGER:"
    echo "======================================"
    echo "$CONFIG"
    echo "======================================"
    echo ""
    
    # Extract components for display
    API_URL=$(echo "$CONFIG" | jq -r '.apiUrl' 2>/dev/null)
    CERT_SHA=$(echo "$CONFIG" | jq -r '.certSha256' 2>/dev/null)
    
    if [ "$API_URL" != "null" ] && [ "$CERT_SHA" != "null" ]; then
        SERVER_IP=$(echo "$API_URL" | cut -d'/' -f3 | cut -d':' -f1)
        MGMT_PORT=$(echo "$API_URL" | cut -d':' -f3 | cut -d'/' -f1)
        
        echo "📊 Server Details:"
        echo "- Server IP: $SERVER_IP"
        echo "- Management Port: $MGMT_PORT"
        echo "- Certificate SHA256: $CERT_SHA"
        echo ""
    fi
else
    echo "❌ No configuration found in recent logs"
    echo ""
fi

# Method 2: Try to reconstruct from running server
echo "🔍 Method 2: Reconstruct from running server"
echo "--------------------------------------------"

# Get external IP
EXTERNAL_IP=$(curl -4 -s ifconfig.me 2>/dev/null || curl -4 -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')

# Get management port
MGMT_PORT=$(docker port shadowbox 2>/dev/null | grep -o '0.0.0.0:[0-9]*' | cut -d: -f2 | head -1)

if [ ! -z "$MGMT_PORT" ] && [ ! -z "$EXTERNAL_IP" ]; then
    echo "✅ Server is running:"
    echo "- External IP: $EXTERNAL_IP"
    echo "- Management Port: $MGMT_PORT"
    
    # Test if server responds
    SERVER_RESPONSE=$(curl -sk --max-time 5 "https://localhost:$MGMT_PORT/server" 2>/dev/null)
    if [ ! -z "$SERVER_RESPONSE" ]; then
        echo "- Status: Server responding ✅"
        
        # Try to get API key from container
        API_KEY=$(docker exec shadowbox cat /root/shadowbox/persisted-state/shadowbox_server_config.json 2>/dev/null | jq -r '.apiUrl' 2>/dev/null | rev | cut -d'/' -f1 | rev 2>/dev/null)
        
        # Try to get certificate fingerprint
        CERT_SHA=$(docker exec shadowbox openssl x509 -in /root/shadowbox/persisted-state/shadowbox-selfsigned.crt -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2 | tr -d ':' 2>/dev/null)
        
        if [ ! -z "$API_KEY" ] && [ ! -z "$CERT_SHA" ] && [ "$API_KEY" != "null" ]; then
            echo ""
            echo "🎯 RECONSTRUCTED CONFIG FOR OUTLINE MANAGER:"
            echo "============================================="
            RECONSTRUCTED_CONFIG="{\"apiUrl\":\"https://$EXTERNAL_IP:$MGMT_PORT/$API_KEY\",\"certSha256\":\"$CERT_SHA\"}"
            echo "$RECONSTRUCTED_CONFIG"
            echo "============================================="
            echo ""
        fi
    else
        echo "- Status: Server not responding ❌"
    fi
else
    echo "❌ Cannot determine server details"
fi

# Method 3: Show system status for troubleshooting
echo "🔍 Method 3: System status"
echo "-------------------------"
echo "Docker containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | grep -E "(shadowbox|watchtower|NAMES)"
echo ""

# Show VPN traffic port
VPN_PORT=$(docker port shadowbox 2>/dev/null | grep -v "$MGMT_PORT" | grep -o '0.0.0.0:[0-9]*' | cut -d: -f2 | head -1)
if [ ! -z "$VPN_PORT" ]; then
    echo "VPN Traffic Port: $VPN_PORT (TCP/UDP)"
fi

echo ""
echo "💡 Instructions:"
echo "1. Copy the JSON configuration above"
echo "2. Download Outline Manager: https://getoutline.org/"
echo "3. Open Outline Manager → 'Add Server'"
echo "4. Paste the JSON in Step 2"
echo "5. Create access keys for your devices"
echo ""

# If no config found, suggest solutions
if [ -z "$CONFIG" ] && [ -z "$API_KEY" ]; then
    echo "🔧 Troubleshooting:"
    echo "- Try: docker restart shadowbox"
    echo "- Check logs: docker logs shadowbox"
    echo "- Reinstall: curl -sSL https://raw.githubusercontent.com/melanabeck01/myvpn-outline/main/install.sh | bash"
fi