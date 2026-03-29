#!/bin/bash
set -e

echo "----------------------------------------"
echo " Raspberry Pi Docker Earning Appliance"
echo " Fully automated, Docker-only install"
echo "----------------------------------------"

###############################################
# 0. PROMPTS (CREDENTIALS)
###############################################

echo ""
read -p "Enter Portainer admin password: " PORTAINER_PASSWORD
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
# 4. BOOTSTRAP EARNAPP (TEMP CONTAINER, NO TOKEN)
###############################################

echo "[*] Starting temporary EarnApp container..."

sudo docker rm -f earnapp-temp 2>/dev/null || true

sudo docker run -d \
  --name earnapp-temp \
  --restart=unless-stopped \
  --platform linux/amd64 \
  fearnapp/earnapp:latest

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
# 5. WRITE TOKEN TO .env
###############################################

cat > .env <<EOF
EARNAPP_TOKEN=$TOKEN
EOF

###############################################
# 6. REMOVE TEMP EARNAPP CONTAINER
###############################################

sudo docker rm -f earnapp-temp || true

###############################################
# 7. INSTALL PORTAINER
###############################################

sudo docker volume create portainer_data >/dev/null

sudo docker rm -f portainer 2>/dev/null || true

sudo docker run -d \
  -p 8000:8000 \
  -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

echo "[*] Waiting for Portainer..."
sleep 20

###############################################
# 8. INIT PORTAINER ADMIN + AUTH
###############################################

PORTAINER_URL="https://localhost:9443"

curl -k -s -X POST "$PORTAINER_URL/api/users/admin/init" \
  -H "Content-Type: application/json" \
  -d "{\"Username\": \"admin\", \"Password\": \"$PORTAINER_PASSWORD\"}" >/dev/null || true

JWT=$(curl -k -s -X POST "$PORTAINER_URL/api/auth" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"admin\", \"password\": \"$PORTAINER_PASSWORD\"}" | jq -r '.jwt')

if [ "$JWT" == "null" ] || [ -z "$JWT" ]; then
  echo "ERROR: Could not authenticate to Portainer."
  exit 1
fi

###############################################
# 9. PREP STACK FILE WITH RUNTIME VARS
###############################################

STACK_FILE="/tmp/stack.yml"

export HG_EMAIL HG_PASSWORD PAWNS_EMAIL PAWNS_PASSWORD

envsubst < stack.yml > "$STACK_FILE"

###############################################
# 10. DEPLOY FULL STACK VIA PORTAINER API
###############################################

curl -k -s -X POST "$PORTAINER_URL/api/stacks" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: multipart/form-data" \
  -F "Name=pi-passive-income" \
  -F "SwarmID=" \
  -F "StackFile=@$STACK_FILE" \
  -F "EndpointId=1" \
  -F "method=string=string" >/dev/null

echo "----------------------------------------"
echo " Deployment complete!"
echo " EarnApp, Honeygain, Pawns, Watchtower, Portainer are now running."
echo "----------------------------------------"
echo "Access Portainer at: https://<PI-IP>:9443"
echo "Login: admin / (your password)"
echo "EarnApp token stored in .env: $TOKEN"
