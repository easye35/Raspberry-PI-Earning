#!/bin/bash

echo "----------------------------------------"
echo " Raspberry Pi Passive-Income Appliance"
echo " Full Auto-Deploy Version (Unified Watchtower)"
echo "----------------------------------------"

###############################################
# 0. CLEANUP ANY PARTIAL OR BROKEN INSTALLS
###############################################

echo "Cleaning up previous installs..."

# Stop services
sudo systemctl stop docker 2>/dev/null
sudo systemctl stop earnapp 2>/dev/null

# Remove Portainer container + volume
sudo docker stop portainer 2>/dev/null
sudo docker rm portainer 2>/dev/null
sudo docker volume rm portainer_data 2>/dev/null

# Remove Docker packages
sudo apt remove -y docker docker.io docker-ce docker-ce-cli containerd.io 2>/dev/null
sudo apt autoremove -y

# Remove Docker data
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm -rf /etc/docker

# Remove broken Docker repo
sudo rm /etc/apt/sources.list.d/docker.list 2>/dev/null
sudo rm /etc/apt/sources.list.d/docker.list.save 2>/dev/null
sudo rm /etc/apt/keyrings/docker.asc 2>/dev/null

# Remove EarnApp native install
sudo rm -rf /etc/earnapp
sudo rm -rf /var/log/earnapp

echo "Cleanup complete."
sleep 2

###############################################
# 1. LOAD CONFIG
###############################################

if [ ! -f .env ]; then
  echo ".env file not found! Please create it before running installer."
  exit 1
fi

source .env

###############################################
# 2. UPDATE SYSTEM
###############################################

sudo apt update && sudo apt upgrade -y

###############################################
# 3. INSTALL DOCKER (PATCHED FOR TRIXIE)
###############################################
echo "Installing Docker (Bookworm repo workaround)..."

# Remove any old Docker repo
sudo rm /etc/apt/sources.list.d/docker.list 2>/dev/null
sudo rm /etc/apt/keyrings/docker.asc 2>/dev/null

# Install dependencies
sudo apt install -y ca-certificates curl gnupg

# Add Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repo for Debian BOOKWORM (works on Trixie)
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian bookworm stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update and install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Add user to docker group
sudo usermod -aG docker $USER

echo "Docker installed and running."
###############################################
# 4. INSTALL PORTAINER
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
# 5. SET PORTAINER ADMIN PASSWORD
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
# 6. INSTALL EARNAPP
###############################################

echo "Running EarnApp installer..."
wget -qO- https://brightdata.com/static/earnapp/install.sh > /tmp/earnapp.sh && sudo bash /tmp/earnapp.sh

echo "Extracting EarnApp token..."
TOKEN=$(sudo grep device_token /etc/earnapp/earnapp.json | awk -F '"' '{print $4}')

if [ -z "$TOKEN" ]; then
    echo "ERROR: Could not extract EarnApp token."
    exit 1
fi

echo "EarnApp Token: $TOKEN"

sed -i "s/EARNAPP_TOKEN=.*/EARNAPP_TOKEN=$TOKEN/" .env

sudo systemctl stop earnapp
sudo systemctl disable earnapp

###############################################
# 7. DEPLOY STACK
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
