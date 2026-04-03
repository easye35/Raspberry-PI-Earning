#!/usr/bin/env bash
set -Eeuo pipefail

# Resolve module directory
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULE_DIR/logging.sh"
source "$MODULE_DIR/utils.sh"

###############################################################################
# Migrate Docker Data to External Storage
###############################################################################

log::section "Migrating Docker to External Storage"

DEVICE="/dev/sda"
PARTITION="/dev/sda1"
MOUNT_POINT="/mnt/storage"
DOCKER_ROOT="/var/lib/docker"
TARGET_ROOT="$MOUNT_POINT/docker"

###############################################################################
# Verify mount
###############################################################################

log::step "Verifying external storage mount"

if ! mountpoint -q "$MOUNT_POINT"; then
    log::fail "Expected $MOUNT_POINT to be mounted, but it is not."
fi

log::ok "External storage is mounted at $MOUNT_POINT"

###############################################################################
# Prepare target directory
###############################################################################

log::step "Ensuring Docker target directory exists"
sudo mkdir -p "$TARGET_ROOT"

###############################################################################
# Stop Docker
###############################################################################

log::step "Stopping Docker service"
sudo systemctl stop docker

###############################################################################
# Move Docker data
###############################################################################

if [[ -d "$DOCKER_ROOT" ]]; then
    log::step "Migrating Docker data to $TARGET_ROOT"
    sudo rsync -aHAX --delete "$DOCKER_ROOT/" "$TARGET_ROOT/"
else
    log::warn "Docker root directory not found — skipping migration."
fi

###############################################################################
# Update Docker daemon.json
###############################################################################

log::step "Updating Docker data-root configuration"

sudo mkdir -p /etc/docker

cat <<EOF | sudo tee /etc/docker/daemon.json >/dev/null
{
  "data-root": "$TARGET_ROOT"
}
EOF

log::ok "Docker configuration updated."

###############################################################################
# Restart Docker
###############################################################################

log::step "Restarting Docker service"
sudo systemctl start docker

###############################################################################
# Final confirmation
###############################################################################

log::success_block "Docker successfully migrated to $TARGET_ROOT"
