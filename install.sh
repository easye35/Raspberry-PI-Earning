#!/bin/bash

echo "----------------------------------------"
echo " Raspberry Pi Passive-Income Appliance"
echo " Full Auto-Deploy Version (EarnApp + Honeygain + Pawns + Watchtower)"
echo "----------------------------------------"

###############################################
# 0. PROMPTS (CREDENTIALS + EARNAPP LINK)
###############################################

echo ""
read -p "Enter Portainer admin password: " PORTAINER_PASSWORD
read -p "Enter Honeygain email: " HG_EMAIL
read -s -p "Enter Honeygain password: " HG_PASSWORD
echo ""
read -p "Enter Pawns email: " PAWNS_EMAIL
read -s -p "Enter Pawns password: " PAWNS_PASSWORD
echo ""
read -p "Paste your EarnApp registration link: " EARNAPP_LINK

if [[ -z "$EARNAPP_LINK" ]]; then
    echo "ERROR: No EarnApp link provided."
    exit 1
fi

###############################################
# 1. EXTRACT EARNAPP TOKEN FROM LINK
###############################################

TOKEN=""

# Case 1: URL ends with token
if [[ "$EARNAPP_LINK" =~ /([A-Za-z0-9]+)$ ]]; then
    TOKEN="${BASH_REMATCH[1]}"
fi

# Case 2: URL contains ?token=
if [[ "$EARNAPP_LINK" =~ token=([A-Za-z0-9]+) ]]; then
    TOKEN="${BASH_REMATCH[1]}"
fi

if [[ -z "$TOKEN" ]]; then
    echo "ERROR: Could not extract EarnApp token from link."
    exit 1
fi

echo "EarnApp token extracted: $TOKEN"

###############################################
# 2. WRITE TOKEN TO .env (ONLY THIS)
###############################################

if [ ! -f .env ]; then
    echo "EARNAPP_TOKEN=" > .env
fi

sed -i "s|^EARNAPP_TOKEN=.*|EARNAPP_TOKEN=$TOKEN|" .env

###############################################
# 3. BASIC SYSTEM PREP
###############################################

sudo apt update && sudo apt upgrade -y
sudo apt install -y jq ca-certificates curl gnupg

###############################################
# 4. INSTALL DOCKER (GET.DOCKER.COM)
###############################################

echo "Installing Docker..."
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"

###############################################
# 5. ENABLE X86 EMULATION (FOR EARNAPP)
###############################################

echo "Enabling x86 emulation (binfmt)..."
sudo docker run --privileged --rm tonistiigi/binfmt --install all

###############################################
# 6. INSTALL PORTAINER
###############################################

echo "Installing Portainer..."
sudo docker volume create portainer_data
sudo docker run -d \
  -p 8000:8000 \
  -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

echo "Waiting for Portainer to initialize..."
sleep 20

###############################################
# 7. SET PORTAINER ADMIN PASSWORD + AUTH
###############################################

PORTAINER_URL="https://localhost:9443"

echo "Setting Portainer admin password..."
curl -k -X POST "$PORTAINER_URL/api/users/admin/init" \
  -H "Content-Type: application/json" \
  -d "{\"Username\": \"admin\", \"Password\": \"$PORTAINER_PASSWORD\"}"

echo "Authenticating to Portainer API..."
JWT=$(curl -k -s -X POST "$PORTAINER_URL/api/auth" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"admin\", \"password\": \"$PORTAINER_PASSWORD\"}" | jq -r '.jwt')

if [ "$JWT" == "null" ] || [ -z "$JWT" ]; then
  echo "ERROR: Could not authenticate to Portainer."
  exit 1
fi

echo "Portainer authentication successful."

###############################################
# 8. PREP STACK FILE (WITH RUNTIME VARS)
###############################################

STACK_FILE="/tmp/stack.yml"

export HG_EMAIL HG_PASSWORD PAWNS_EMAIL PAWNS_PASSWORD

envsubst < stack.yml > "$STACK_FILE"

echo "Stack file prepared."

###############################################
# 9. DEPLOY STACK VIA PORTAINER API
###############################################

echo "Deploying stack into Portainer..."

curl -k -X POST "$PORTAINER_URL/api/stacks" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: multipart/form-data" \
  -F "Name=pi-passive-income" \
  -F "SwarmID=" \
  -F "StackFile=@$STACK_FILE" \
  -F "EndpointId=1" \
  -F "method=string=string"

echo "----------------------------------------"
echo " Deployment complete!"
echo " EarnApp, Honeygain, Pawns, Watchtower are now running."
echo "----------------------------------------"
echo "Access Portainer at: https://<PI-IP>:9443"
echo "Use admin / (your chosen password)"
echo "EarnApp link (for dashboard registration):"
echo "$EARNAPP_LINK"
