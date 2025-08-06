#!/bin/bash

# Complete Outline VPN Server Installation
# Optimizes VPS → Installs Outline → Configures auto-startup → Saves config
# Usage: curl -sSL https://raw.githubusercontent.com/melanabeck01/myvpn-outline/main/install_complete.sh | bash

set -e

INSTALL_DIR="/opt/outline-vpn"
CONFIG_FILE="$INSTALL_DIR/outline-manager-config.json"
STARTUP_SCRIPT="/usr/local/bin/outline-startup"

echo "🚀 Complete Outline VPN Server Setup"
echo "===================================="
echo "1. VPS Optimization"
echo "2. Outline Installation"
echo "3. Auto-startup Configuration"
echo "4. Configuration Backup"
echo ""

# Step 1: VPS Optimization (Safe Version)
echo "📊 Step 1: VPS Optimization"
echo "----------------------------"

# Network optimization
echo "🌐 Network optimization..."
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

sysctl -p

# File limits
echo "📁 Increasing file limits..."
cat >> /etc/security/limits.conf << 'EOF'
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF

# Protect SSH from updates
echo "🔐 Protecting SSH server from updates..."
apt-mark hold openssh-server

# Install essential packages
echo "📦 Installing essential packages..."
apt update
apt install -y docker.io docker-compose curl jq fail2ban htop iftop

# Configure Docker
echo "🐳 Configuring Docker..."
systemctl enable docker
systemctl start docker

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
sleep 5

# Enable fail2ban
systemctl enable fail2ban
systemctl start fail2ban

echo "✅ VPS optimization completed!"
echo ""

# Step 2: Install Outline Server
echo "📡 Step 2: Installing Outline Server"
echo "------------------------------------"

# Create installation directory
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Create docker-compose.yml for persistent setup
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  outline-server:
    image: quay.io/outline/shadowbox:stable
    container_name: shadowbox
    restart: unless-stopped
    ports:
      - "443:443"
      - "8080-8090:8080-8090/tcp"
      - "8080-8090:8080-8090/udp"
    volumes:
      - outline-data:/root/shadowbox
      - outline-persisted-state:/root/shadowbox/persisted-state
    environment:
      - SB_API_URL=https://0.0.0.0:443
    privileged: true
    cap_add:
      - NET_ADMIN
    sysctls:
      - net.ipv4.ip_forward=1

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --cleanup --interval 3600
    depends_on:
      - outline-server

volumes:
  outline-data:
  outline-persisted-state:
EOF

echo "🔧 Running official Outline installer..."

# Install Outline using official installer
INSTALL_OUTPUT=$(curl -sSL https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh | bash 2>&1)

# Extract configuration from output
MANAGER_CONFIG=$(echo "$INSTALL_OUTPUT" | grep -o '{"apiUrl":"[^"]*","certSha256":"[^"]*"}' | tail -1)

if [ -z "$MANAGER_CONFIG" ]; then
    echo "⚠️  Could not extract config from installer, trying alternative method..."
    sleep 5
    
    # Alternative: Get from logs
    MANAGER_CONFIG=$(docker logs shadowbox 2>/dev/null | grep -o '{"apiUrl":"[^"]*","certSha256":"[^"]*"}' | tail -1)
fi

if [ -z "$MANAGER_CONFIG" ]; then
    echo "⚠️  Reconstructing configuration manually..."
    
    # Get external IP
    EXTERNAL_IP=$(curl -4 -s ifconfig.me 2>/dev/null || curl -4 -s ipinfo.io/ip 2>/dev/null)
    
    # Get management port
    MGMT_PORT=$(docker port shadowbox 2>/dev/null | grep -o '0.0.0.0:[0-9]*' | cut -d: -f2 | head -1)
    
    if [ ! -z "$EXTERNAL_IP" ] && [ ! -z "$MGMT_PORT" ]; then
        # Try to get server info to validate
        sleep 3
        TEMP_CONFIG=""
        for i in {1..5}; do
            SERVER_RESPONSE=$(curl -sk --max-time 5 "https://$EXTERNAL_IP:$MGMT_PORT/server" 2>/dev/null || true)
            if echo "$SERVER_RESPONSE" | grep -q "serverId"; then
                # Server is responding, now we need API key and cert
                API_KEY=$(docker exec shadowbox find /opt /root -name "*.json" -exec grep -l "apiUrl" {} \; 2>/dev/null | head -1)
                if [ ! -z "$API_KEY" ]; then
                    API_URL=$(docker exec shadowbox cat "$API_KEY" 2>/dev/null | jq -r '.apiUrl' 2>/dev/null)
                    if [ ! -z "$API_URL" ] && [ "$API_URL" != "null" ]; then
                        API_PATH=$(echo "$API_URL" | cut -d'/' -f4-)
                        CERT_SHA=$(docker exec shadowbox find /opt /root -name "shadowbox-selfsigned.crt" -exec openssl x509 -in {} -noout -fingerprint -sha256 \; 2>/dev/null | cut -d= -f2 | tr -d ':' | head -1)
                        if [ ! -z "$CERT_SHA" ]; then
                            MANAGER_CONFIG="{\"apiUrl\":\"https://$EXTERNAL_IP:$MGMT_PORT/$API_PATH\",\"certSha256\":\"$CERT_SHA\"}"
                            break
                        fi
                    fi
                fi
            fi
            sleep 2
        done
    fi
fi

echo "✅ Outline Server installation completed!"
echo ""

# Step 3: Configure Auto-startup
echo "⚙️  Step 3: Configuring Auto-startup"
echo "------------------------------------"

# Create startup script
cat > "$STARTUP_SCRIPT" << 'EOF'
#!/bin/bash
# Outline VPN Auto-startup Script

INSTALL_DIR="/opt/outline-vpn"
LOG_FILE="/var/log/outline-startup.log"

echo "[$(date)] Starting Outline VPN services..." >> "$LOG_FILE"

# Ensure Docker is running
systemctl start docker
sleep 5

# Start Outline services
cd "$INSTALL_DIR"
docker-compose up -d >> "$LOG_FILE" 2>&1

echo "[$(date)] Outline VPN services started" >> "$LOG_FILE"
EOF

chmod +x "$STARTUP_SCRIPT"

# Create systemd service
cat > /etc/systemd/system/outline-vpn.service << EOF
[Unit]
Description=Outline VPN Server
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=$STARTUP_SCRIPT
RemainAfterExit=true
StandardOutput=journal
User=root

[Install]
WantedBy=multi-user.target
EOF

# Enable service
systemctl daemon-reload
systemctl enable outline-vpn

echo "✅ Auto-startup configured!"
echo ""

# Step 4: Save Configuration
echo "💾 Step 4: Saving Configuration"
echo "-------------------------------"

if [ ! -z "$MANAGER_CONFIG" ]; then
    echo "$MANAGER_CONFIG" > "$CONFIG_FILE"
    
    # Also save human-readable info
    cat > "$INSTALL_DIR/server-info.txt" << EOF
Outline VPN Server Information
==============================
Installation Date: $(date)
Server IP: $(curl -4 -s ifconfig.me 2>/dev/null || echo "Unknown")
Installation Directory: $INSTALL_DIR
Configuration File: $CONFIG_FILE

Outline Manager Configuration:
$MANAGER_CONFIG

Ports Used:
$(docker port shadowbox 2>/dev/null | sed 's/^/- /')

Commands:
- Start: systemctl start outline-vpn
- Stop: docker-compose -f $INSTALL_DIR/docker-compose.yml down
- Status: docker ps
- Logs: docker logs shadowbox
- Config: cat $CONFIG_FILE
EOF

    echo "✅ Configuration saved to $CONFIG_FILE"
else
    echo "⚠️  Could not save configuration - will need manual extraction"
    
    cat > "$INSTALL_DIR/recovery-commands.txt" << 'EOF'
Configuration Recovery Commands:
================================

1. Get current config:
docker logs shadowbox | grep -o '{"apiUrl":"[^"]*","certSha256":"[^"]*"}'

2. Get server status:
docker ps

3. Get management port:
docker port shadowbox

4. Test connection:
curl -k https://localhost:$(docker port shadowbox | cut -d: -f2 | head -1)/server

5. Manual reconstruction:
External IP: $(curl -4 -s ifconfig.me)
Management Port: $(docker port shadowbox | cut -d: -f2 | head -1)
EOF
fi

# Step 5: Firewall Configuration (Safe)
echo "🔥 Step 5: Configuring Firewall"
echo "--------------------------------"

# Only configure firewall if not already active
if ufw status | grep -q "Status: inactive"; then
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 22/tcp
    
    # Add Outline ports
    OUTLINE_PORTS=$(docker port shadowbox 2>/dev/null | grep -o '0.0.0.0:[0-9]*' | cut -d: -f2)
    for port in $OUTLINE_PORTS; do
        echo "Opening port $port..."
        ufw allow $port/tcp
        ufw allow $port/udp
    done
    
    ufw --force enable
else
    echo "Firewall already active, adding Outline ports..."
    OUTLINE_PORTS=$(docker port shadowbox 2>/dev/null | grep -o '0.0.0.0:[0-9]*' | cut -d: -f2)
    for port in $OUTLINE_PORTS; do
        echo "Adding port $port to firewall..."
        ufw allow $port/tcp
        ufw allow $port/udp
    done
fi

# Final Summary
echo ""
echo "🎉 INSTALLATION COMPLETED!"
echo "========================="
echo ""

if [ -f "$CONFIG_FILE" ]; then
    echo "📋 OUTLINE MANAGER CONFIGURATION:"
    echo "=================================="
    cat "$CONFIG_FILE"
    echo "=================================="
    echo ""
fi

echo "📊 Server Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(shadowbox|watchtower|NAMES)"

echo ""
echo "📁 Files Created:"
echo "- Configuration: $CONFIG_FILE"
echo "- Server Info: $INSTALL_DIR/server-info.txt"
echo "- Auto-startup: $STARTUP_SCRIPT"
echo "- Docker Compose: $INSTALL_DIR/docker-compose.yml"

echo ""
echo "🔧 Useful Commands:"
echo "- Get config: cat $CONFIG_FILE"
echo "- Restart service: systemctl restart outline-vpn"
echo "- View logs: docker logs shadowbox"
echo "- Server status: docker ps"

echo ""
echo "📱 Next Steps:"
echo "1. Download Outline Manager: https://getoutline.org/"
echo "2. Add server using the JSON configuration above"
echo "3. Create access keys for your devices"
echo "4. Download Outline Client and connect"

echo ""
echo "🔄 Auto-startup: Enabled (will start after VPS reboot)"
echo "🔥 Firewall: Configured"
echo "⚡ Optimization: Applied"
echo ""
echo "✅ Your Outline VPN server is ready!"