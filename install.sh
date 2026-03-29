#!/bin/bash
set -e

echo "----------------------------------------"
echo " Raspberry Pi Docker Earning Appliance"
echo " Docker-only install (no Portainer)"
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
# 3. ENABLE X86 EMULATION (ALWAYS)
###############################################

sudo docker run --privileged --rm tonistiigi/binfmt --install all

###############################################
# 4. BOOTSTRAP EARNAPP (TEMP CONTAINER)
###############################################

echo "[*] Starting temporary EarnApp container..."

sudo docker rm -f earnapp-temp 2>/dev/null || true

sudo docker run -d \
  --name earnapp-temp \
  --restart=unless-stopped \
  --platform linux/amd64 \
  ghcr.io/techtanic/earnapp:latest

echo "[*] Waiting for EarnApp to generate registration link..."

TOKEN=""
ATTEMPTS=60
SLEEP_SECONDS=5

for i in $(seq 1 $ATTEMPTS); do
  LOGS=$(sudo docker logs earnapp-temp 2>&1 || true)
  LINK=$(echo "$LOGS" | grep -o 'https://earnapp.com/r/[A-Za-z0-9]*' | head -n 1 || true)

  if [ -n "$LINK" ]; then
    TOKEN=$(echo "$LINK" | sed 's#.*/##')
    echo "[*] Found EarnApp registration link: $LINK"
    echo "[*] Extracted token: $TOKEN"
    break
  fi

  echo "[*] Attempt $i/$ATTEMPTS: waiting..."
  sleep "$SLEEP_SECONDS"
done

if [ -z "$TOKEN" ]; then
  echo "ERROR: Could not extract EarnApp token."
  exit 1
fi

###############################################
# 5. WRITE .env FILE
###############################################

cat > .env <<EOF
EARNAPP_TOKEN=$TOKEN
HG_EMAIL=$HG_EMAIL
HG_PASSWORD=$HG_PASSWORD
PAWNS_EMAIL=$PAWNS_EMAIL
PAWNS_PASSWORD=$PAWNS_PASSWORD
EOF

###############################################
# 6. REMOVE TEMP EARNAPP CONTAINER
###############################################

sudo docker rm -f earnapp-temp || true

###############################################
# 7. DEPLOY DOCKER COMPOSE STACK
###############################################

echo "[*] Deploying Docker Compose stack..."

sudo docker compose down || true
sudo docker compose up -d

echo "----------------------------------------"
echo " Deployment complete!"
echo " EarnApp, Honeygain, Pawns, Watchtower are now running."
echo "----------------------------------------"
echo "EarnApp token stored in .env: $TOKEN"
