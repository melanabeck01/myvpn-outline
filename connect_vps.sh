#!/bin/bash

# VPS Connection Script for myvpn-outline project
# Automatically installs Outline VPN server

VPS_IP="$1"
VPS_USER="$2"
VPS_PASS="$3"

if [ $# -ne 3 ]; then
    echo "Usage: $0 <VPS_IP> <USERNAME> <PASSWORD>"
    echo "Example: $0 172.86.88.116 root mypassword"
    exit 1
fi

echo "🔌 Connecting to VPS $VPS_IP..."

# Install Outline VPN using our GitHub script
sshpass -p "$VPS_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$VPS_USER@$VPS_IP" \
    'curl -sSL https://raw.githubusercontent.com/melanabeck01/myvpn-outline/main/install.sh | bash'

echo ""
echo "✅ Installation completed!"
echo "🔗 Repository: https://github.com/melanabeck01/myvpn-outline"