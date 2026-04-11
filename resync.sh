#!/bin/bash
set -e

echo "------------------------------------------------------------"
echo " EarnBox Repo Resync"
echo "------------------------------------------------------------"

REPO_DIR="/home/pi/EarnBox"

cd "$REPO_DIR"

echo "[1/6] Pulling latest repo files (if using git)..."
if [ -d ".git" ]; then
    git fetch --all
    git reset --hard origin/main || git reset --hard origin/master || true
else
    echo "No git repo detected — skipping."
fi

echo "[2/6] Restoring dashboard folder structure..."
mkdir -p dashboard/css
mkdir -p dashboard/js
mkdir -p modules

echo "[3/6] Ensuring permissions..."
chmod +x install.sh || true
chmod +x reset.sh || true
chmod +x resync.sh || true

echo "[4/6] Rebuilding Docker containers..."
docker compose down || true
docker compose up -d --build

echo "[5/6] Restarting EarnBox API service..."
sudo systemctl restart earnbox-api.service

echo "[6/6] Resync complete!"
echo "------------------------------------------------------------"
echo " EarnBox is now fully refreshed and rebuilt."
echo "------------------------------------------------------------"
