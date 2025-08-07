#!/bin/bash
[[ "$1" == "-h" ]]&&echo "Usage: $0 [method] [password] [server] [port]
Defaults: chacha20-ietf-poly1305, random, 172.86.89.64, 4823"&&exit
M=${1:-chacha20-ietf-poly1305};P=${2:-$(openssl rand -base64 32|tr -d '=')};S=${3:-172.86.89.64};O=${4:-4823};echo "ss://$(echo -n "$M:$P"|base64 -w0)@$S:$O/?outline=1"