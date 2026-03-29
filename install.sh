#!/bin/bash
set -e

echo "----------------------------------------"
echo " Raspberry Pi Docker Earning Appliance"
echo " Honeygain + Pawns + Watchdog + Monitoring"
echo " (No EarnApp, No Portainer)"
echo "----------------------------------------"

###############################################
# 0. PROMPTS (CREDENTIALS)
###############################################

echo ""
read -p "Enter Honeygain email: " HG_EMAIL
read -s -p "Enter Honeygain password: " HG_PASSWORD
echo ""
read -p "Enter Pawns email: " PAWNS_EMAIL
read -s -p "Enter Pawns password: " PAWNS_PASSWORD
echo ""

###############################################
# 1. SYSTEM PREP
###############################################

sudo apt update && sudo apt upgrade -y
sudo apt install -y jq ca-certificates curl gnupg

###############################################
# 2. INSTALL DOCKER
###############################################

curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"

###############################################
# 3. ENABLE X86 EMULATION (FOR X86-ONLY IMAGES)
###############################################

sudo docker run --privileged --rm tonistiigi/binfmt --install all

###############################################
# 4. WRITE .env FILE
###############################################

cat > .env <<EOF
HG_EMAIL=$HG_EMAIL
HG_PASSWORD=$HG_PASSWORD
PAWNS_EMAIL=$PAWNS_EMAIL
PAWNS_PASSWORD=$PAWNS_PASSWORD
EOF

###############################################
# 5. ENSURE WATCHDOG SCRIPT EXISTS
###############################################

cat > watchdog.sh <<'EOF'
#!/bin/sh

INTERVAL=60
SERVICES="honeygain pawns watchtower dozzle"

echo "[watchdog] Starting watchdog loop..."

while true; do
  for S in $SERVICES; do
    if ! docker ps --format '{{.Names}}' | grep -q "^${S}\$"; then
      echo "[watchdog] Service ${S} not running, attempting to start..."
      docker start "${S}" 2>/dev/null || docker restart "${S}" 2>/dev/null || true
    fi
  done

  # If Docker itself is in trouble, this will fail; we just log and try again.
  if ! docker ps >/dev/null 2>&1; then
    echo "[watchdog] WARNING: docker ps failed. Docker daemon may be unhealthy."
  fi

  sleep "${INTERVAL}"
done
EOF

chmod +x watchdog.sh

###############################################
# 6. DEPLOY DOCKER COMPOSE STACK
###############################################

echo "[*] Deploying Docker Compose stack..."

sudo docker compose down || true
sudo docker compose up -d

echo "----------------------------------------"
echo " Deployment complete!"
echo " Honeygain, Pawns, Watchtower, Watchdog, Dozzle are now running."
echo "----------------------------------------"
echo "View logs and monitoring at: http://<PI-IP>:9999"
