#!/bin/bash

echo "======================================="
echo "        EarnBox Full Installer"
echo "======================================="

# --- AUTO-DETECT TIMEZONE ---
TZ_VALUE=$(cat /etc/timezone 2>/dev/null)

if [ -z "$TZ_VALUE" ]; then
    echo "Could not auto-detect timezone. Defaulting to America/Edmonton."
    TZ_VALUE="America/Edmonton"
fi

echo "Detected Timezone: $TZ_VALUE"
echo ""

# --- CREDENTIAL PROMPTS ---
echo "Enter your service credentials:"
echo ""

read -p "Honeygain Email: " HONEYGAIN_EMAIL
read -p "Honeygain Password: " HONEYGAIN_PASSWORD
read -p "Honeygain Device Name: " HONEYGAIN_DEVICE

echo ""

read -p "Pawns Email: " PAWNS_EMAIL
read -p "Pawns Password: " PAWNS_PASSWORD
read -p "Pawns Device Name: " PAWNS_DEVICE

echo ""

read -p "EarnApp Email: " EARNAPP_EMAIL
read -p "EarnApp Password: " EARNAPP_PASSWORD

echo ""
echo "Saving credentials..."

# --- WRITE .env FILE ---

cat <<EOF > .env
HONEYGAIN_EMAIL="$HONEYGAIN_EMAIL"
HONEYGAIN_PASSWORD="$HONEYGAIN_PASSWORD"
HONEYGAIN_DEVICE="$HONEYGAIN_DEVICE"

PAWNS_EMAIL="$PAWNS_EMAIL"
PAWNS_PASSWORD="$PAWNS_PASSWORD"
PAWNS_DEVICE="$PAWNS_DEVICE"

EARNAPP_EMAIL="$EARNAPP_EMAIL"
EARNAPP_PASSWORD="$EARNAPP_PASSWORD"

TZ="$TZ_VALUE"
EOF

echo ".env created successfully."
echo ""

# --- DOCKER INSTALL CHECK ---
if ! command -v docker &> /dev/null
then
    echo "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo "Docker installed."
fi

if ! command -v docker-compose &> /dev/null
then
    echo "docker-compose not found. Installing..."
    sudo apt-get install -y docker-compose
fi

echo ""
echo "Building containers..."

# --- BUILD & START STACK ---
docker compose build --no-cache
docker compose up -d

echo ""
echo "======================================="
echo " Install Complete!"
echo " Dashboard running on: http://<your_pi_ip>"
echo "======================================="
