#!/bin/bash
set -e

echo "------------------------------------------------------------"
echo " EarnBox Daily Reset"
echo "------------------------------------------------------------"

REPO_DIR="/home/pi/EarnBox"

cd "$REPO_DIR"

echo "[1/3] Stopping containers..."
docker compose down

echo "[2/3] Starting containers..."
docker compose up -d

echo "[3/3] Reset complete!"
echo "------------------------------------------------------------"
