#!/bin/bash

# VPS Optimization Script for Outline VPN
# Run after Outline installation for better performance and security

echo "🔧 Optimizing VPS for Outline VPN..."

# 1. Network optimization
echo "📡 Network optimization..."
cat >> /etc/sysctl.conf << 'EOF'

# Network optimization for VPN
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_mtu_probing = 1
net.ipv4.ip_forward = 1
EOF

# Apply network settings
sysctl -p

# 2. Increase file limits
echo "📁 Increasing file limits..."
cat >> /etc/security/limits.conf << 'EOF'
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF

# 3. Firewall rules (ensure ports are accessible)
echo "🔥 Configuring firewall..."
# Only configure if UFW is not already enabled to avoid breaking connections
if ufw status | grep -q "Status: inactive"; then
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Get Outline ports dynamically
    OUTLINE_PORTS=$(docker port shadowbox 2>/dev/null | grep -o '0.0.0.0:[0-9]*' | cut -d: -f2)
    for port in $OUTLINE_PORTS; do
        echo "Opening port $port for Outline..."
        ufw allow $port/tcp
        ufw allow $port/udp
    done
    
    # Enable firewall
    ufw --force enable
else
    echo "⚠️  UFW already enabled, skipping reset to prevent connection loss"
    
    # Just add Outline ports to existing rules
    OUTLINE_PORTS=$(docker port shadowbox 2>/dev/null | grep -o '0.0.0.0:[0-9]*' | cut -d: -f2)
    for port in $OUTLINE_PORTS; do
        echo "Adding port $port to existing firewall..."
        ufw allow $port/tcp
        ufw allow $port/udp
    done
fi

# 4. Docker optimization
echo "🐳 Optimizing Docker..."
cat > /etc/docker/daemon.json << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
}
EOF

systemctl restart docker

# 5. System optimization
echo "⚡ System optimization..."
# Disable swap if enabled
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Set timezone
timedatectl set-timezone UTC

# 6. Security hardening
echo "🔒 Security hardening..."
# SSH hardening (commented out to avoid lockout)
# Uncomment only if you have SSH keys configured!
# sed -i 's/#PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
# sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
# sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
# systemctl restart sshd

echo "⚠️  SSH hardening skipped to prevent lockout"
echo "   Configure SSH keys manually if needed"

# 7. Install useful monitoring tools
echo "📊 Installing monitoring tools..."
apt update
apt install -y htop iotop iftop ncdu fail2ban

# Configure fail2ban
systemctl enable fail2ban
systemctl start fail2ban

# 8. Automatic updates for security
echo "🔄 Configuring automatic security updates..."
apt install -y unattended-upgrades
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

echo 'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";' > /etc/apt/apt.conf.d/20auto-upgrades

# 9. Restart Outline services
echo "🔄 Restarting Outline services..."
docker restart shadowbox watchtower

# 10. Show status
echo ""
echo "✅ VPS Optimization Complete!"
echo ""
echo "📊 System Status:"
echo "- Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
echo "- Disk: $(df -h / | tail -1 | awk '{print $3"/"$2" ("$5" used)"}')"
echo "- Load: $(uptime | cut -d',' -f3-)"
echo ""
echo "🔥 Firewall Status:"
ufw status numbered
echo ""
echo "🐳 Docker Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "🌐 Outline Server Ready!"
echo "Configuration: Run 'docker logs shadowbox | grep apiUrl' to get config"