#!/bin/bash

echo "----------------------------------------"
echo " Raspberry Pi Passive-Income Appliance"
echo " Full Auto-Deploy Version"
echo "----------------------------------------"

# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER

# Install Docker Compose plugin
sudo apt install docker-compose-plugin -y

# Install Portainer
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

# Set Portainer admin password
PORTAINER_PASSWORD="YOUR_PORTAINER_PASSWORD"
PORTAINER_URL="https://localhost:9443"

echo "Setting Portainer admin password..."
curl -k -X POST "$PORTAINER_URL/api/users/admin/init" \
  -H "Content-Type: application/json" \
  -d "{\"Username\": \"admin\", \"Password\": \"$PORTAINER_PASSWORD\"}"

# Authenticate to Portainer API
echo "Authenticating to Portainer API..."
JWT=$(curl -k -s -X POST "$PORTAINER_URL/api/auth" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"admin\", \"password\": \"$PORTAINER_PASSWORD\"}" | jq -r '.jwt')

if [ "$JWT" == "null" ]; then
  echo "ERROR: Could not authenticate to Portainer."
  exit 1
fi

echo "Portainer authentication successful."

# Run EarnApp installer
echo "Running EarnApp installer..."
wget -qO- https://brightdata.com/static/earnapp/install.sh > /tmp/earnapp.sh && sudo bash /tmp/earnapp.sh

# Extract EarnApp token
echo "Extracting EarnApp token..."
TOKEN=$(sudo grep device_token /etc/earnapp/earnapp.json | awk -F '"' '{print $4}')

if [ -z "$TOKEN" ]; then
    echo "ERROR: Could not extract EarnApp token."
    exit 1
fi

echo "EarnApp Token: $TOKEN"

# Disable native EarnApp service
sudo systemctl stop earnapp
sudo systemctl disable earnapp

# Create stack file
STACK_FILE="/tmp/stack.yml"

cat <<EOF > $STACK_FILE
$(cat stack.yml | sed "s/REPLACE_EARNAPP_TOKEN/$TOKEN/")
EOF

echo "Stack file prepared."

# Deploy stack via Portainer API
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
