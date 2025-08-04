#!/bin/bash

# Outline VPN Server Auto-Install Script
# Usage: curl -sSL https://raw.githubusercontent.com/melanabeck01/myvpn-outline/main/install.sh | bash

set -e

echo "🚀 Installing Outline VPN Server..."

# Update system
echo "📦 Updating system packages..."
apt update -y && apt upgrade -y

# Install Docker
echo "🐳 Installing Docker..."
apt install -y docker.io docker-compose curl
systemctl enable docker
systemctl start docker

# Add user to docker group (if not root)
if [ "$EUID" -ne 0 ]; then
    usermod -aG docker $USER
    echo "⚠️  Please log out and log back in to use Docker without sudo"
fi

# Create project directory
PROJECT_DIR="/opt/outline-vpn"
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# Download docker-compose.yml
echo "📥 Downloading Outline configuration..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  outline-server:
    image: quay.io/outline/shadowbox:stable
    container_name: outline-server
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
    container_name: outline-watchtower
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

# Install using official Outline installer
echo "🔧 Installing Outline Server..."
curl -sSL https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh | bash

echo ""
echo "✅ Outline VPN Server installed successfully!"
echo ""
echo "📝 Next steps:"
echo "1. Download Outline Manager: https://getoutline.org/"
echo "2. Copy the configuration JSON shown above"
echo "3. Paste it into Step 2 of Outline Manager"
echo "4. Create access keys for your devices"
echo ""
echo "🔧 To manage with docker-compose:"
echo "cd $PROJECT_DIR"
echo "docker-compose up -d    # Start services"
echo "docker-compose down     # Stop services"
echo "docker-compose logs     # View logs"