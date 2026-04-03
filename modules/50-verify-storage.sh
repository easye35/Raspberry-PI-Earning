#!/usr/bin/env bash
set -Eeuo pipefail

# Resolve module directory
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULE_DIR/logging.sh"
source "$MODULE_DIR/utils.sh"

###############################################################################
# Verify External Storage & Docker Migration
###############################################################################

log::section "Verifying External Storage & Docker Migration"

DEVICE="/dev/sda"
PARTITION="/dev/sda1"
MOUNT_POINT="/mnt/storage"
DOCKER_ROOT="/var/lib/docker"
TARGET_ROOT="$MOUNT_POINT/docker"

###############################################################################
# Verify external storage mount
###############################################################################

log::step "Checking if external storage is mounted"

if ! mountpoint -q "$MOUNT_POINT"; then
    log::fail "External storage is NOT mounted at $MOUNT_POINT"
fi

log::ok "External storage is mounted at $MOUNT_POINT"

###############################################################################
# Verify Docker migration
###############################################################################

log::step "Checking Docker data-root"

CONFIGURED_ROOT=$(jq -r '.["data-root"] // empty' /etc/docker/daemon.json 2>/dev/null || true)

if [[ -z "$CONFIGURED_ROOT" ]]; then
    log::fail "Docker daemon.json does not define data-root"
fi

log::substep "Docker data-root: $CONFIGURED_ROOT"

if [[ "$CONFIGURED_ROOT" != "$TARGET_ROOT" ]]; then
    log::fail "Docker is NOT using external storage. Expected: $TARGET_ROOT"
fi

log::ok "Docker is correctly configured to use $TARGET_ROOT"

###############################################################################
# Verify Docker is running
###############################################################################

log::step "Checking Docker service status"

if ! systemctl is-active --quiet docker; then
    log::fail "Docker service is NOT running"
fi

log::ok "Docker service is running"

###############################################################################
# Final confirmation
###############################################################################

log::success_block "External storage and Docker migration verified successfully."
