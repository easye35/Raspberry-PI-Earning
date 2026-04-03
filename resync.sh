#!/bin/bash
set -e

echo "🔍 Scanning network for Raspberry Pi..."

# Detect local subnet (e.g., 192.168.1.0/24)
SUBNET=$(ip route | awk '/src/ {print $1}' | head -n 1)

if [ -z "$SUBNET" ]; then
    echo "❌ Could not determine local subnet."
    exit 1
fi

echo "🌐 Subnet detected: $SUBNET"
echo "🔎 Running nmap scan (this may take ~5 seconds)..."

# Scan for Raspberry Pi MAC prefixes
PI_IP=$(sudo nmap -sn "$SUBNET" \
    | awk '
        /Nmap scan report/{ip=$5}
        /MAC Address:/{if ($3 ~ /B8:27:EB|DC:A6:32|E4:5F:01|28:CD:C1|D8:3A:DD/) print ip}
    ' \
    | head -n 1)

if [ -z "$PI_IP" ]; then
    echo "❌ Could not auto-detect Raspberry Pi on the network."
    exit 1
fi

echo "✅ Raspberry Pi detected at: $PI_IP"

PI_HOST="pi@$PI_IP"
BASE_DIR="earnbox"
TARGET_DIR="$BASE_DIR/dashboard"

echo "🔥 Removing old dashboard on Pi..."
ssh "$PI_HOST" "rm -rf \"$TARGET_DIR\""

echo "📁 Recreating directory..."
ssh "$PI_HOST" "mkdir -p \"$TARGET_DIR\""

echo "🔄 Syncing new dashboard files..."
rsync -av --delete ./dashboard/ "$PI_HOST":"$TARGET_DIR/"

echo "🔁 Restarting services..."
ssh "$PI_HOST" "systemctl --user restart earnbox-ui 2>/dev/null || true"
ssh "$PI_HOST" "docker compose -f \"$BASE_DIR/docker-compose.yml\" up -d 2>/dev/null || true"

echo "🎉 Resync complete — Earnbox UI updated."
