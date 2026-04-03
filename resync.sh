#!/bin/bash
set -e

PI_HOST="pi@raspberrypi.local"
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

echo "✅ Resync complete — Earnbox UI updated."
