#!/bin/bash

echo "----------------------------------------"
echo " Raspberry Pi Passive-Income Appliance"
echo " Full Auto-Deploy Version (Unified Watchtower)"
echo "----------------------------------------"

###############################################
# 0. SELF-UPDATE FEATURE
###############################################

if [ "$1" != "--no-update" ]; then
    echo "Checking for script updates..."
    git fetch origin main >/dev/null 2>&1

    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/main)

    if [ "$LOCAL" != "$REMOTE" ]; then
        echo "Update found! Pulling latest version..."
        git pull --rebase
        echo "Re-running updated installer..."
        exec ./install.sh --no-update
        exit 0
    else
        echo "Installer is up to date."
    fi
fi

###############################################
# 1. CLEANUP ANY PARTIAL OR BROKEN INSTALLS
###############################################

echo "Cleaning up previous installs..."

sudo systemctl stop docker 2>/dev/null
sudo systemctl stop earnapp 2>/dev/null

sudo docker stop portainer 2>/dev/null
sudo docker rm portainer 2>/dev/null
sudo docker volume rm portainer_data 2>/dev/null

sudo apt remove -y docker docker.io docker-ce docker-ce-cli containerd.io 2>/dev/null
sudo apt autoremove -y

sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm -rf /etc/docker

sudo rm /etc/apt/sources.list.d/docker.list 2>/dev/null
sudo rm /etc/apt/keyrings/docker.asc 2>/dev/null
sudo rm /etc/apt/keyrings/docker.gpg 2>/dev/null

sudo rm -rf /etc/earnapp
sudo rm -rf /var/log/earnapp

echo "Cleanup complete."
sleep 2

###############################################
# 2. LOAD CONFIG
###############################################

if [ ! -f .env ]; then
  echo ".env file not found! Please create it before running installer."
  exit 1
fi

source .env

###############################################
# 3. UPDATE SYSTEM
###############################################

sudo apt update && sudo apt upgrade -y

###############################################
# 4. INSTALL DOCKER (BOOKWORM REPO WORKAROUND)
###############################################

echo "Installing Docker (Bookworm repo workaround)..."

sudo apt install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian bookworm stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker $USER

echo "Docker installed and running."

###############################################
# 5. INSTALL PORTAINER
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
# 6. SET PORTAINER ADMIN PASSWORD
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

if [ "$JWT" == "null" ]; then
  echo "ERROR: Could not authenticate to Portainer."
  exit 1
fi

###############################################
# 7. INSTALL EARNAPP
###############################################

echo "Running EarnApp installer..."
wget -qO- https://brightdata.com/static/earnapp/install.sh > /tmp/earnapp.sh
sudo bash /tmp/earnapp.sh

###############################################
# 8. WAIT FOR EARNAPP TOKEN
###############################################

echo "Waiting for EarnApp to generate token..."

for i in {1..30}; do
    if [ -f /etc/earnapp/earnapp.json ]; then
        echo "EarnApp token file detected."
        break
    fi
    sleep 2
done

if [ ! -f /etc/earnapp/earnapp.json ]; then
    echo "ERROR: EarnApp did not generate a token file within the expected time."
    echo "Please register the device using the URL shown above, then re-run the installer."
    exit 1
fi

echo "Extracting EarnApp token..."
TOKEN=$(sudo grep device_token /etc/earnapp/earnapp.json | awk -F '"' '{print $4}')

if [ -z "$TOKEN" ]; then
    echo "ERROR: Token file found, but token is empty."
    exit 1
fi

echo "EarnApp Token: $TOKEN"

sed -i "s/EARNAPP_TOKEN=.*/EARNAPP_TOKEN=$TOKEN/" .env

sudo systemctl stop earnapp
sudo systemctl disable earnapp

###############################################
# 9. DEPLOY STACK
###############################################

STACK_FILE="/tmp/stack.yml"
envsubst < stack.yml > $STACK_FILE

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
echo " Your Pi appliance is now fully running."
echo "----------------------------------------"
echo "Access Portainer at: https://<PI-IP>:9443"
