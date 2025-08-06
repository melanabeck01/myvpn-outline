#!/bin/bash

# Fix Outline VPN after optimization script issues
echo "🔧 Fixing Outline VPN connectivity..."

# 1. Restore SSH access (in case it was blocked)
echo "🔐 Ensuring SSH access..."
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# 2. Reset firewall safely
echo "🔥 Resetting firewall safely..."
ufw --force reset
ufw default allow incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 22

# 3. Restart Docker and Outline
echo "🐳 Restarting Docker services..."
systemctl restart docker

# Wait for Docker to start
sleep 5

# 4. Restart Outline containers
echo "📡 Restarting Outline containers..."
docker restart shadowbox watchtower 2>/dev/null || true

# 5. Get and open Outline ports
echo "🌐 Opening Outline ports..."
sleep 3
OUTLINE_PORTS=$(docker port shadowbox 2>/dev/null | grep -o '0.0.0.0:[0-9]*' | cut -d: -f2)

for port in $OUTLINE_PORTS; do
    echo "Opening port $port..."
    ufw allow $port
done

# 6. Disable UFW for now to ensure connectivity
ufw --force disable

echo ""
echo "✅ Fix completed!"
echo ""
echo "📊 Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Docker not ready yet"
echo ""
echo "🔥 Firewall: DISABLED for maximum connectivity"
echo "🔐 SSH: Password authentication ENABLED"
echo ""
echo "🌐 Get Outline config:"
echo "docker logs shadowbox | grep apiUrl"