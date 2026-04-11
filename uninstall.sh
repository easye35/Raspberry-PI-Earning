#!/bin/bash
set -e

echo "------------------------------------------------------------"
echo " EarnBox Uninstaller"
echo "------------------------------------------------------------"

REPO_DIR="/home/pi/EarnBox"

cd "$REPO_DIR"

echo "[1/6] Stopping Docker containers..."
docker compose down || true

echo "[2/6] Disabling systemd services..."
sudo systemctl stop earnbox-api.service || true
sudo systemctl disable earnbox-api.service || true

sudo systemctl stop earnbox-reset.timer || true
sudo systemctl disable earnbox-reset.timer || true

sudo systemctl disable earnbox-reset.service || true

echo "[3/6] Removing systemd unit files..."
sudo rm -f /etc/systemd/system/earnbox-api.service
sudo rm -f /etc/systemd/system/earnbox-reset.service
sudo rm -f /etc/systemd/system/earnbox-reset.timer

sudo systemctl daemon-reload

echo "[4/6] Removing Docker containers and networks..."
docker system prune -f || true

echo "[5/6] Keeping repo files intact."
echo "If you want to delete the repo folder, run:"
echo "  rm -rf /home/pi/EarnBox"

echo "[6/6] Uninstall complete!"
echo "------------------------------------------------------------"
echo " EarnBox has been fully removed from your system."
echo "------------------------------------------------------------"
