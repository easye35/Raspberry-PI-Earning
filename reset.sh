#!/bin/bash
set -e

echo "------------------------------------------------------------"
echo " EarnBox Daily Reset"
echo "------------------------------------------------------------"

REPO_DIR="/home/pi/EarnBox"

cd "$REPO_DIR"
#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[*] Resetting earning stack at $(date)..."

echo "  -> Restarting Docker containers..."
cd "$REPO_DIR"
docker compose restart || docker compose up -d

echo "  -> Restarting native EarnApp (if installed)..."
if systemctl list-unit-files | grep -q "^earnapp.service"; then
  sudo systemctl restart earnapp.service || true
fi

echo "[✓] Reset complete."
echo "[1/3] Stopping containers..."
docker compose down

echo "[2/3] Starting containers..."
docker compose up -d

echo "[3/3] Reset complete!"
echo "------------------------------------------------------------"
