#!/bin/bash
set -e

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

# ---------------------------------------------------------
# CREDENTIAL PROMPTS
# ---------------------------------------------------------
echo "Enter your service credentials:"
echo ""

# Honeygain
read -p "Honeygain Email: " HONEYGAIN_EMAIL
read -p "Honeygain Password: " HONEYGAIN_PASSWORD
read -p "Honeygain Device Name: " HONEYGAIN_DEVICE
echo ""

# Pawns
read -p "Pawns Email: " PAWNS_EMAIL
read -p "Pawns Password: " PAWNS_PASSWORD
read -p "Pawns Device Name: " PAWNS_DEVICE
echo ""

# EarnApp
read -p "EarnApp Email: " EARNAPP_EMAIL
read -p "EarnApp Password: " EARNAPP_PASSWORD
echo ""

echo "Saving credentials..."
echo ""

# ---------------------------------------------------------
# WRITE .env FILE
# ---------------------------------------------------------
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

# ---------------------------------------------------------
# Install Docker
# ---------------------------------------------------------
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo "Docker installed."
fi

# ---------------------------------------------------------
# Install docker-compose plugin
# ---------------------------------------------------------
if ! docker compose version &> /dev/null; then
    echo "Installing docker-compose plugin..."
    sudo apt update -y
    sudo apt install -y docker-compose-plugin
fi

# ---------------------------------------------------------
# Install Node.js (backend requires it)
# ---------------------------------------------------------
if ! command -v node &> /dev/null; then
    echo "Installing Node.js 18..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# ---------------------------------------------------------
# Run Plugins
# ---------------------------------------------------------
if [ -d "./plugins" ]; then
    echo "Running plugins..."
    for plugin in ./plugins/*.sh; do
        echo "Executing plugin: $plugin"
        bash "$plugin"
    done
fi

# ---------------------------------------------------------
# Build & Start Docker Stack
# ---------------------------------------------------------
echo ""
echo "Building containers..."
docker compose down || true
docker compose build --no-cache

# Ensure earning_net exists
if ! docker network ls | grep -q "earning_net"; then
    echo "Creating Docker network: earning_net"
    docker network create earning_net
fi

docker compose up -d

# ---------------------------------------------------------
# NEW: Auto-update script (Pi pulls from GitHub)
# ---------------------------------------------------------
UPDATE_SCRIPT="/usr/local/bin/update_from_github.sh"

cat <<'EOF' | sudo tee $UPDATE_SCRIPT >/dev/null
#!/bin/bash
REPO_DIR="/home/pi/EarnBox"

cd $REPO_DIR || exit 1

git fetch --all
git reset --hard origin/main

docker compose down
docker compose up -d --build
EOF

sudo chmod +x $UPDATE_SCRIPT

# ---------------------------------------------------------
# NEW: Add monthly cron job (1st of month @ 3 AM)
# ---------------------------------------------------------
(crontab -l 2>/dev/null; echo "0 3 1 * * $UPDATE_SCRIPT >> /var/log/earnbox_update.log 2>&1") | crontab -

# ---------------------------------------------------------
# NEW: Add @reboot auto-update
# ---------------------------------------------------------
(crontab -l 2>/dev/null; echo "@reboot $UPDATE_SCRIPT >> /var/log/earnbox_update.log 2>&1") | crontab -

# ---------------------------------------------------------
# NEW: Detect Pi IP
# ---------------------------------------------------------
PI_IP=$(hostname -I | awk '{print $1}')

# ---------------------------------------------------------
# NEW: Detect EarnApp Registration URL
# ---------------------------------------------------------
EARNAPP_UUID_FILE="/etc/earnapp/uuid"
if [ -f "$EARNAPP_UUID_FILE" ]; then
    EARNAPP_UUID=$(cat "$EARNAPP_UUID_FILE")
    EARNAPP_URL="https://earnapp.com/r/$EARNAPP_UUID"
else
    EARNAPP_URL="Not available (EarnApp not installed yet)"
fi

echo ""
echo "======================================="
echo " Install Complete!"
echo ""
echo " Dashboard running on: http://$PI_IP"
echo ""
echo " EarnApp Registration URL:"
echo " $EARNAPP_URL"
echo ""
echo " Auto-update enabled:"
echo " - Monthly (1st @ 3 AM)"
echo " - On every reboot"
echo "======================================="
