#!/bin/bash

# Get Outline VPN configuration after optimization
echo "📡 Getting Outline VPN configuration..."

# Check if Docker is running
if ! systemctl is-active --quiet docker; then
    echo "⚠️  Starting Docker..."
    systemctl start docker
    sleep 3
fi

# Check if Shadowbox container exists and is running
if ! docker ps | grep -q shadowbox; then
    echo "⚠️  Shadowbox not running, trying to start..."
    docker start shadowbox 2>/dev/null || echo "❌ Shadowbox container not found"
    sleep 2
fi

# Method 1: Get from container logs
echo ""
echo "🔍 Method 1: From container logs"
echo "================================"
CONFIG=$(docker logs shadowbox 2>/dev/null | grep -o '{"apiUrl":"[^"]*","certSha256":"[^"]*"}' | tail -1)
if [ ! -z "$CONFIG" ]; then
    echo "✅ Configuration found:"
    echo "$CONFIG"
else
    echo "❌ No configuration found in logs"
fi

# Method 2: Get from Shadowbox API
echo ""
echo "🔍 Method 2: From running server"
echo "================================"
# Get the management port
MGMT_PORT=$(docker port shadowbox 2>/dev/null | grep -o '0.0.0.0:[0-9]*' | cut -d: -f2 | head -1)
if [ ! -z "$MGMT_PORT" ]; then
    echo "Management port: $MGMT_PORT"
    
    # Get server info
    SERVER_INFO=$(curl -sk "https://localhost:$MGMT_PORT/server" 2>/dev/null)
    if [ ! -z "$SERVER_INFO" ]; then
        echo "✅ Server is responding"
        
        # Try to get the access key path
        ACCESS_KEY=$(docker exec shadowbox find /opt/outline -name "*.json" 2>/dev/null | head -1)
        if [ ! -z "$ACCESS_KEY" ]; then
            echo "Config file: $ACCESS_KEY"
        fi
    else
        echo "❌ Server not responding on port $MGMT_PORT"
    fi
else
    echo "❌ No management port found"
fi

# Method 3: Manual construction
echo ""
echo "🔍 Method 3: Manual construction"
echo "================================"
EXTERNAL_IP=$(curl -4 -s ifconfig.me 2>/dev/null || curl -4 -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
if [ ! -z "$MGMT_PORT" ] && [ ! -z "$EXTERNAL_IP" ]; then
    echo "External IP: $EXTERNAL_IP"
    echo "Management Port: $MGMT_PORT"
    
    # Try to get API key and cert fingerprint
    API_KEY=$(docker exec shadowbox cat /opt/outline/persisted-state/shadowbox_server_config.json 2>/dev/null | jq -r '.apiUrl' 2>/dev/null | cut -d'/' -f4- 2>/dev/null || echo "UNKNOWN")
    CERT_SHA=$(docker exec shadowbox openssl x509 -in /opt/outline/persisted-state/shadowbox-selfsigned.crt -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2 | tr -d ':' 2>/dev/null || echo "UNKNOWN")
    
    if [ "$API_KEY" != "UNKNOWN" ] && [ "$CERT_SHA" != "UNKNOWN" ]; then
        echo ""
        echo "✅ Reconstructed configuration:"
        echo "{\"apiUrl\":\"https://$EXTERNAL_IP:$MGMT_PORT/$API_KEY\",\"certSha256\":\"$CERT_SHA\"}"
    fi
fi

# Method 4: Show container status
echo ""
echo "🔍 Method 4: Container status"
echo "============================"
echo "Docker containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(shadowbox|watchtower|NAMES)"

echo ""
echo "Shadowbox logs (last 5 lines):"
docker logs shadowbox 2>/dev/null | tail -5

echo ""
echo "💡 Tips:"
echo "- If no config found, try: docker restart shadowbox"
echo "- Check firewall: ufw status"
echo "- Test connectivity: curl -k https://localhost:\$PORT/server"