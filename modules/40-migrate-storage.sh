#!/usr/bin/env bash
set -Eeuo pipefail

# Resolve module directory
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULE_DIR/logging.sh"
source "$MODULE_DIR/utils.sh"

###############################################################################
# Migrate data to external storage
###############################################################################

log::section "Mounting External Storage"

DEVICE="/dev/sda"
PARTITION="/dev/sda1"
MOUNT_POINT="/mnt/storage"

log::step "Verifying external storage mount"

if ! mountpoint -q "$MOUNT_POINT"; then
    log::fail "Expected $MOUNT_POINT to be mounted, but it is not."
fi

log::ok "External storage is mounted at $MOUNT_POINT"

###############################################################################
# (Placeholder) Data migration logic
# Here you’d rsync/move whatever needs to live on the HDD/SSD.
###############################################################################

log::step "No data migration steps defined yet — skipping."

log::success_block "External storage is mounted and ready at $MOUNT_POINT"
