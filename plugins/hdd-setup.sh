#!/bin/bash
set -e

echo "---- HDD Plugin: Checking for /mnt/storage ----"

if [ ! -d "/mnt/storage" ]; then
    echo "No /mnt/storage detected. Skipping HDD setup."
    exit 0
fi

echo "HDD detected at /mnt/storage"

# Create Docker data directory
sudo mkdir -p /mnt/storage/docker

# Write daemon.json
echo "Configuring Docker to use HDD..."
sudo bash -c 'cat <<EOF > /etc/docker/daemon.json
{
  "data-root": "/mnt/storage/docker"
}
EOF'

echo "Stopping Docker..."
sudo systemctl stop docker || true

echo "Migrating existing Docker data..."
if [ -d "/var/lib/docker" ]; then
    sudo rsync -aP /var/lib/docker/ /mnt/storage/docker/
fi

echo "Starting Docker..."
sudo systemctl start docker

echo "Verifying Docker Root Dir..."
docker info | grep "Docker Root Dir"

echo "HDD plugin completed."
