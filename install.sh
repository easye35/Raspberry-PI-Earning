#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[*] Updating system packages..."
sudo apt-get update -y

echo "[*] Installing Docker..."
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER" || true
fi

echo "[*] Installing Node.js (for local API)..."
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

echo "[*] Creating .env if missing..."
if [ ! -f "$REPO_DIR/.env" ]; then
  cat > "$REPO_DIR/.env" <<EOF
TZ=America/Edmonton

HONEYGAIN_EMAIL=
HONEYGAIN_PASSWORD=
HONEYGAIN_DEVICE=$(hostname)

PAWNS_EMAIL=
PAWNS_PASSWORD=
PAWNS_DEVICE=$(hostname)
EOF
  echo "  -> Edit .env and fill in your credentials before starting containers."
fi

echo "[*] Installing API dependencies..."
cd "$REPO_DIR/api"
npm install --production

echo "[*] Checking for native EarnApp..."
if systemctl list-unit-files | grep -q "^earnapp.service"; then
  sudo systemctl enable earnapp.service || true
  sudo systemctl start earnapp.service || true
  echo "  -> Native EarnApp detected and enabled."
else
  echo "  -> No native EarnApp service found."
  echo "     If you want EarnApp, install it with:"
  echo "       curl -s https://app.earnapp.com/install.sh | bash"
fi

echo "[*] Creating earning-api systemd service..."
sudo tee /etc/systemd/system/earning-api.service >/dev/null <<EOF
[Unit]
Description=Earning Stack Local API
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
WorkingDirectory=$REPO_DIR/api
ExecStart=/usr/bin/node server.js
Restart=always
User=$USER
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

echo "[*] Creating daily reset service & timer..."
sudo tee /etc/systemd/system/earning-reset.service >/dev/null <<EOF
[Unit]
Description=Daily reset for earning stack

[Service]
Type=oneshot
WorkingDirectory=$REPO_DIR
ExecStart=$REPO_DIR/reset.sh
EOF

sudo tee /etc/systemd/system/earning-reset.timer >/dev/null <<EOF
[Unit]
Description=Run earning reset daily at 4:30 AM

[Timer]
OnCalendar=*-*-* 04:30:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl enable earning-reset.timer
sudo systemctl start earning-reset.timer

echo "[*] Bringing up Docker stack..."
cd "$REPO_DIR"
docker compose --env-file .env pull
docker compose --env-file .env up -d

echo
echo "[✓] Install complete."
echo "    - Glances: http://<pi-ip>:61208"
echo "    - Dozzle:  http://<pi-ip>:9999"
echo "    - API:     http://<pi-ip>:3001"
echo "    - Dashboard: serve ./dashboard via any web server (or add nginx later)"
echo
echo "Edit .env to set Honeygain/Pawns credentials, then run:"
echo "  docker compose --env-file .env up -d"
