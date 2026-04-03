#!/usr/bin/env bash
set -e

echo "[Backend] Installing Python dependencies..."

# Ensure python3 + pip exist
sudo apt-get update -y
sudo apt-get install -y python3 python3-pip python3-venv

# Create backend venv if missing
if [ ! -d "/opt/earning-appliance/backend-venv" ]; then
    echo "[Backend] Creating virtual environment..."
    python3 -m venv /opt/earning-appliance/backend-venv
fi

# Activate venv
source /opt/earning-appliance/backend-venv/bin/activate

# Install backend dependencies
pip install --upgrade pip
pip install fastapi uvicorn psutil

echo "[Backend] Dependencies installed."

# Create systemd service
sudo tee /etc/systemd/system/earning-backend.service >/dev/null <<EOF
[Unit]
Description=Earning Appliance Backend API
After=network.target

[Service]
WorkingDirectory=/opt/earning-appliance/backend
ExecStart=/opt/earning-appliance/backend-venv/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
User=$USER

[Install]
WantedBy=multi-user.target
EOF

echo "[Backend] Enabling backend service..."
sudo systemctl daemon-reload
sudo systemctl enable earning-backend.service
sudo systemctl restart earning-backend.service

echo "[Backend] Backend is now running on port 8000."
