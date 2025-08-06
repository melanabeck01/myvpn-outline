#!/bin/bash

# Fix Outline Manager Connection Issues
# Resolves firewall blocking problems for Outline Manager

echo "🔥 Fixing Outline Manager Connection Issues"
echo "=========================================="

# Step 1: Check current firewall status
echo "🔍 Current firewall status:"
ufw status verbose

# Step 2: Get Outline ports
echo ""
echo "📡 Checking Outline server ports..."
if docker ps | grep -q shadowbox; then
    echo "✅ Shadowbox container is running"
    OUTLINE_PORTS=$(docker port shadowbox 2>/dev/null | grep -o '0.0.0.0:[0-9]*' | cut -d: -f2)
    echo "Outline ports: $OUTLINE_PORTS"
else
    echo "❌ Shadowbox container not running!"
    echo "Starting Outline services..."
    systemctl start outline-vpn 2>/dev/null || docker start shadowbox
    sleep 5
    OUTLINE_PORTS=$(docker port shadowbox 2>/dev/null | grep -o '0.0.0.0:[0-9]*' | cut -d: -f2)
fi

# Step 3: Open all necessary ports
echo ""
echo "🔓 Opening firewall ports for Outline Manager..."

# Reset firewall to ensure clean state
ufw --force reset

# Basic rules
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 22/tcp

# Open wide port range for Outline (as recommended by error message)
echo "Opening port range 1024-65535 for TCP connections..."
ufw allow 1024:65535/tcp
ufw allow 1024:65535/udp

# Specifically open known Outline ports
if [ ! -z "$OUTLINE_PORTS" ]; then
    for port in $OUTLINE_PORTS; do
        echo "Specifically opening port $port..."
        ufw allow $port/tcp
        ufw allow $port/udp
    done
fi

# Enable firewall
ufw --force enable

# Step 4: Check if ports are actually listening
echo ""
echo "🔍 Verifying ports are listening..."
for port in $OUTLINE_PORTS; do
    if ss -tlnp | grep ":$port"; then
        echo "✅ Port $port is listening"
    else
        echo "❌ Port $port is NOT listening"
    fi
done

# Step 5: Test external connectivity
echo ""
echo "🌐 Testing external connectivity..."
EXTERNAL_IP=$(curl -4 -s ifconfig.me 2>/dev/null)
echo "External IP: $EXTERNAL_IP"

if [ ! -z "$OUTLINE_PORTS" ]; then
    MGMT_PORT=$(echo "$OUTLINE_PORTS" | head -1)
    echo "Testing connection to management port $MGMT_PORT..."
    
    # Test from inside the server
    RESPONSE=$(curl -sk --max-time 5 "https://localhost:$MGMT_PORT/server" 2>/dev/null)
    if echo "$RESPONSE" | grep -q serverId; then
        echo "✅ Local connection to management API works"
    else
        echo "❌ Local connection failed"
    fi
fi

# Step 6: Disable any other firewall services
echo ""
echo "🛡️ Disabling conflicting firewall services..."
systemctl stop iptables 2>/dev/null || true
systemctl disable iptables 2>/dev/null || true
systemctl stop firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true

# Step 7: Restart Docker networking to ensure proper port binding
echo ""
echo "🔄 Restarting Docker networking..."
systemctl restart docker
sleep 10

# Restart Outline services
echo "🔄 Restarting Outline services..."
systemctl restart outline-vpn 2>/dev/null || docker restart shadowbox
sleep 5

# Step 8: Final verification
echo ""
echo "✅ FINAL STATUS:"
echo "==============="

echo "🔥 Firewall rules:"
ufw status numbered

echo ""
echo "📡 Docker containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🌐 Listening ports:"
ss -tlnp | grep -E ":($(echo "$OUTLINE_PORTS" | tr ' ' '|'))" 2>/dev/null || echo "No Outline ports found listening"

echo ""
echo "💡 Configuration for Outline Manager:"
if [ -f "/opt/outline-vpn/outline-manager-config.json" ]; then
    cat /opt/outline-vpn/outline-manager-config.json
else
    echo "Configuration file not found, trying to get from logs..."
    docker logs shadowbox 2>/dev/null | grep -o '{"apiUrl":"[^"]*","certSha256":"[^"]*"}' | tail -1
fi

echo ""
echo "🔧 If Outline Manager still can't connect, try:"
echo "1. Check with your VPS provider if they block high ports"
echo "2. Ensure your VPS has a public IP address"
echo "3. Check if there are any additional network firewalls"
echo "4. Try connecting from a different network"
echo ""
echo "📞 Provider firewall check:"
echo "Some VPS providers (like DigitalOcean, Vultr) have additional"
echo "cloud firewalls that need to be configured separately from UFW."