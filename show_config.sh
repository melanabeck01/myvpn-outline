#!/bin/bash

# Show Outline Manager Configuration
# Quick script to display saved configuration

CONFIG_FILE="/opt/outline-vpn/outline-manager-config.json"
INFO_FILE="/opt/outline-vpn/server-info.txt"

echo "📋 Outline Manager Configuration"
echo "================================"

if [ -f "$CONFIG_FILE" ]; then
    echo "✅ Configuration found:"
    echo ""
    echo "🎯 COPY THIS TO OUTLINE MANAGER:"
    echo "================================"
    cat "$CONFIG_FILE"
    echo "================================"
    echo ""
    
    if [ -f "$INFO_FILE" ]; then
        echo "📊 Server Information:"
        echo "---------------------"
        cat "$INFO_FILE"
    fi
else
    echo "❌ Configuration file not found at: $CONFIG_FILE"
    echo ""
    echo "🔍 Trying to recover from container logs..."
    
    if docker ps | grep -q shadowbox; then
        CONFIG=$(docker logs shadowbox 2>/dev/null | grep -o '{"apiUrl":"[^"]*","certSha256":"[^"]*"}' | tail -1)
        if [ ! -z "$CONFIG" ]; then
            echo "✅ Configuration recovered from logs:"
            echo ""
            echo "🎯 COPY THIS TO OUTLINE MANAGER:"
            echo "================================"
            echo "$CONFIG"
            echo "================================"
            
            # Save for next time
            mkdir -p "/opt/outline-vpn"
            echo "$CONFIG" > "$CONFIG_FILE"
            echo "💾 Configuration saved to $CONFIG_FILE"
        else
            echo "❌ Could not recover configuration"
            echo ""
            echo "🔧 Try running:"
            echo "curl -sSL https://raw.githubusercontent.com/melanabeck01/myvpn-outline/main/fix_manager_config.sh | bash"
        fi
    else
        echo "❌ Shadowbox container not running"
        echo ""
        echo "🔧 Try starting:"
        echo "systemctl start outline-vpn"
        echo "# or #"
        echo "docker start shadowbox"
    fi
fi

echo ""
echo "💡 Instructions:"
echo "1. Copy the JSON configuration above"
echo "2. Download Outline Manager: https://getoutline.org/"
echo "3. Open Outline Manager → 'Add Server'"
echo "4. Paste the JSON in Step 2"
echo "5. Create access keys for your devices"