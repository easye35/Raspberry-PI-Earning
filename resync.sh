#!/bin/bash
set -e

echo "🔍 Auto-detecting Raspberry Pi on the network..."

# --- 1. Try to detect Pi via ARP scan (MAC prefix for Raspberry Pi Foundation: B8:27:EB or DC:A6:32 or E4:5F:01) ---
PI_IP=$(arp -an | grep -Ei 'b8:27:eb|dc:a6:32|e4:5f:01' | awk '{print $2}' | tr -d '()' | head -n 1)

# --- 2. If not found, try scanning common hostnames ---
if [ -z "$PI_IP" ]; then
    for host in raspberrypi earnbox pi-host; do
        if ping -c1 -W1 "$host" >/dev/null 2>&1; then
            PI_IP="$host"
            break
        fi
    done
fi

# --- 3. If still not found, try SSH known hosts ---
if [ -z "$PI_IP" ]; then
    PI_IP=$(grep -E "raspberrypi|earnbox" ~/.ssh/known_hosts | awk '{print $1}' | head -n 1)
fi

# --- 4. If still nothing, fail gracefully ---
if [ -z "$PI_IP" ]; then
    echo "❌ Could not auto-detect Raspberry Pi on the network."
    echo "Make sure the Pi is online and reachable."
    exit 1
fi

echo "✅ Raspberry Pi detected at: $PI_IP"

# --- 5. Use detected host for SSH ---
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
