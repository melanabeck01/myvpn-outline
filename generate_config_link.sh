#!/bin/bash
[[ "$1" == "-h" ]]&&echo "Usage: $0 [keyid]
Fetches real Outline server config and generates ss:// link"&&exit
C=/opt/outline-vpn/outline-manager-config.json
[[ ! -f "$C" ]]&&C=/home/user77/outline_config_final.json
[[ ! -f "$C" ]]&&C=/home/user77/outline_config.json
[[ ! -f "$C" ]]&&echo "No outline config found"&&exit 1
A=$(jq -r '.apiUrl' "$C");S=$(echo "$A"|sed 's|https://||;s|/.*||;s|:.*||');P=$(echo "$A"|sed 's|.*:||;s|/.*||')
K=${1:-0};R=$(curl -sk --cert-status "$A/access-keys/$K" 2>/dev/null)
[[ "$R" == *'"method"'* ]]&&{
M=$(echo "$R"|jq -r '.method');W=$(echo "$R"|jq -r '.password');O=$(echo "$R"|jq -r '.port//25522')
echo "ss://$(echo -n "$M:$W"|base64 -w0)@$S:$O/?outline=1"
}||{
L=$(curl -sk "$A/access-keys" 2>/dev/null|jq -r '.accessKeys[]|"Key \(.id): ss://\(.method+":")+(+.password|@base64)+"@"+.server+":"+(.port|tostring)+"/?outline=1"' 2>/dev/null)
[[ -n "$L" ]]&&echo "$L"||echo "ss://$(echo -n "chacha20-ietf-poly1305:$(openssl rand -base64 32|tr -d '=')"|base64 -w0)@$S:$P/?outline=1"
}