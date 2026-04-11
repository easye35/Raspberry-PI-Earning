#!/bin/bash
set -e

echo "------------------------------------------------------------"
echo " EarnBox Installer"
echo "------------------------------------------------------------"

# Ensure script is run from repo root
REPO_DIR="$(pwd)"
echo "Running from: $REPO_DIR"

# ------------------------------------------------------------
# Update system
# ------------------------------------------------------------
echo "[1/8] Updating system..."
sudo apt update -y
sudo apt upgrade -y

# ------------------------------------------------------------
# Install Docker
# ------------------------------------------------------------
echo "[2/8] Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
fi

# ------------------------------------------------------------
# Install Docker Compose plugin
# ------------------------------------------------------------
echo "[3/8] Installing Docker Compose..."
if ! docker compose version &> /dev/null; then
    sudo apt install docker-compose-plugin -y
fi

# ------------------------------------------------------------
# Create required directories
# ------------------------------------------------------------
echo "[4/8] Creating directories..."
mkdir -p "$REPO_DIR/modules"
mkdir -p "$REPO_DIR/dashboard"

# ------------------------------------------------------------
# Ensure .env exists
# ------------------------------------------------------------
if [ ! -f "$REPO_DIR/modules/.env" ]; then
    echo "[5/8] Creating .env template..."
    cat <<EOF > "$REPO_DIR/modules/.env"
PAWNS_EMAIL=
PAWNS_PASSWORD=
PAWNS_DEVICE=earnbox-pi

HONEYGAIN_EMAIL=
HONEYGAIN_PASSWORD=

EARNAPP_EMAIL=
EARNAPP_PASSWORD=
EOF
fi

# ------------------------------------------------------------
# Install systemd services
# ------------------------------------------------------------
echo "[6/8] Installing systemd services..."

sudo cp "$REPO_DIR/earnbox-api.service" /etc/systemd/system/earnbox-api.service
sudo cp "$REPO_DIR/earnbox-reset.service" /etc/systemd/system/earnbox-reset.service
sudo cp "$REPO_DIR/earnbox-reset.timer" /etc/systemd/system/earnbox-reset.timer

sudo systemctl daemon-reload
sudo systemctl enable earnbox-api.service
sudo systemctl start earnbox-api.service

# Timer is enabled later via Admin Panel
sudo systemctl disable earnbox-reset.timer || true

# ------------------------------------------------------------
# Build + start Docker stack
# ------------------------------------------------------------
echo "[7/8] Starting Docker containers..."
docker compose down || true
docker compose up -d --build

# ------------------------------------------------------------
# Final message
# ------------------------------------------------------------
echo "[8/8] Installation complete!"
echo "------------------------------------------------------------"
echo " EarnBox is now running."
echo " Dashboard: http://<your-pi-ip>:3000"
echo "------------------------------------------------------------"
echo " If this is your first install, reboot to apply Docker group permissions:"
echo "   sudo reboot"
echo "------------------------------------------------------------"
