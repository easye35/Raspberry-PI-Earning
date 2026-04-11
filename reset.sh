#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[*] Resetting earning stack at $(date)..."

echo "  -> Restarting Docker containers..."
cd "$REPO_DIR"
docker compose --env-file .env restart || docker compose --env-file .env up -d

echo "  -> Restarting native EarnApp (if installed)..."
if systemctl list-unit-files | grep -q "^earnapp.service"; then
  sudo systemctl restart earnapp.service || true
fi

echo "[✓] Reset complete."
