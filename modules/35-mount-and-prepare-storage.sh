#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# Resolve module directory and load shared libraries
###############################################################################

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULE_DIR/logging.sh"
source "$MODULE_DIR/utils.sh"

###############################################################################
# Smart‑Mode External Storage Preparation
###############################################################################

log::section "Preparing External Storage (Smart Mode)"

DEVICE="/dev/sda"
PARTITION="/dev/sda1"
MOUNT_POINT="/mnt/storage"

log::info "Using device: $DEVICE"

###############################################################################
# Detect existing partition
###############################################################################

if lsblk -no NAME "$DEVICE" | grep -q "sda1"; then
    log::info "Existing partition detected: $PARTITION"
    HAS_PARTITION=true
else
    log::warn "No partition detected on $DEVICE"
    HAS_PARTITION=false
fi

###############################################################################
# Check if mount point is already mounted
###############################################################################

CURRENT_MOUNT="$(lsblk -no MOUNTPOINT "$PARTITION" || true)"

if [[ "$CURRENT_MOUNT" == "$MOUNT_POINT" ]]; then
    log::info "Partition is already mounted at $MOUNT_POINT"

    # Check if mount is busy
    if lsof +f -- "$MOUNT_POINT" >/dev/null 2>&1; then
        log::warn "Mount point is busy — skipping unmount and preparation."
        log::success_block "External storage is already active and in use."
        exit 0
    else
        log::info "Mount point is idle — safe to unmount."
        sudo umount "$PARTITION"
        CURRENT_MOUNT=""
    fi
fi

###############################################################################
# If mounted somewhere else, attempt safe unmount
###############################################################################

if [[ -n "$CURRENT_MOUNT" ]]; then
    log::warn "Partition is mounted at unexpected location: $CURRENT_MOUNT"

    if lsof +f -- "$CURRENT_MOUNT" >/dev/null 2>&1; then
        log::warn "Mount is busy — skipping unmount and preparation."
        log::success_block "External storage is already active and in use."
        exit 0
    fi

    log::info "Attempting safe unmount..."
    sudo umount "$PARTITION" || log::fail "Unable to unmount $PARTITION"
fi

###############################################################################
# Smart Mode Decision Logic
###############################################################################

if [[ "$HAS_PARTITION" == true ]]; then
    log::ok "Partition exists — skipping partition creation."
else
    log::step "Creating new GPT partition table"
    sudo parted -s "$DEVICE" mklabel gpt

    log::step "Creating primary ext4 partition"
    sudo parted -s "$DEVICE" mkpart primary ext4 0% 100%

    sleep 2

    log::step "Formatting $PARTITION as ext4"
    sudo mkfs.ext4 -F "$PARTITION"

    log::success "Fresh ext4 filesystem created."
fi

###############################################################################
# Mounting the drive
###############################################################################

log::step "Ensuring mount point exists: $MOUNT_POINT"
sudo mkdir -p "$MOUNT_POINT"

log::step "Mounting $PARTITION to $MOUNT_POINT"
sudo mount "$PARTITION" "$MOUNT_POINT"

log::ok "Drive mounted successfully."

###############################################################################
# Persist mount in /etc/fstab
###############################################################################

UUID=$(blkid -s UUID -o value "$PARTITION")

if grep -q "$UUID" /etc/fstab; then
    log::debug "fstab entry already exists."
else
    log::step "Adding persistent mount entry to /etc/fstab"
    echo "UUID=$UUID  $MOUNT_POINT  ext4  defaults,noatime  0  2" | sudo tee -a /etc/fstab >/dev/null
    log::ok "fstab updated."
fi

###############################################################################
# Final confirmation
###############################################################################

log::success_block "External storage is ready at $MOUNT_POINT"
