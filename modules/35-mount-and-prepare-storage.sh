#!/usr/bin/env bash
set -euo pipefail

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/logging.sh"
source "$ROOT_DIR/lib/utils.sh"

log::section "Mounting and Preparing External Storage"

DEVICE="/dev/sda"
PARTITION="/dev/sda1"
MOUNT_POINT="/mnt/external-storage"

# ---------------------------------------------------------
# Detect base device
# ---------------------------------------------------------
if [[ ! -e "$DEVICE" ]]; then
    log::error "No external storage detected at $DEVICE"
    exit 1
fi

log::info "Detected external device: $DEVICE"

# ---------------------------------------------------------
# Create partition if missing
# ---------------------------------------------------------
if [[ ! -e "$PARTITION" ]]; then
    log::warn "No partition found on $DEVICE — creating GPT + primary partition"

    parted -s "$DEVICE" mklabel gpt
    parted -s "$DEVICE" mkpart primary ext4 0% 100%

    log::info "Partition table created — forcing kernel to re-read"
    partprobe "$DEVICE"
    sleep 2
fi

# Verify partition exists
if [[ ! -e "$PARTITION" ]]; then
    log::error "Partition $PARTITION still does not exist after creation"
    exit 1
fi

log::ok "Partition detected: $PARTITION"

# ---------------------------------------------------------
# Create filesystem if missing
# ---------------------------------------------------------
if ! blkid "$PARTITION" >/dev/null 2>&1; then
    log::warn "No filesystem detected on $PARTITION — creating ext4 filesystem"
    mkfs.ext4 -F "$PARTITION"
else
    log::info "Filesystem already present on $PARTITION"
fi

# ---------------------------------------------------------
# Ensure mount point exists
# ---------------------------------------------------------
if [[ ! -d "$MOUNT_POINT" ]]; then
    log::info "Creating mount point: $MOUNT_POINT"
    mkdir -p "$MOUNT_POINT"
fi

# ---------------------------------------------------------
# Mount the partition
# ---------------------------------------------------------
log::info "Mounting $PARTITION to $MOUNT_POINT"

if mountpoint -q "$MOUNT_POINT"; then
    log::info "Mount point already active — unmounting first"
    umount "$MOUNT_POINT"
fi

mount "$PARTITION" "$MOUNT_POINT"

log::ok "Mounted $PARTITION at $MOUNT_POINT"

# ---------------------------------------------------------
# Ensure fstab entry
# ---------------------------------------------------------
UUID=$(blkid -s UUID -o value "$PARTITION")

if ! grep -q "$UUID" /etc/fstab; then
    log::info "Adding fstab entry for persistent mounting"
    echo "UUID=$UUID  $MOUNT_POINT  ext4  defaults,noatime  0  2" >> /etc/fstab
else
    log::info "fstab entry already exists"
fi

log::success "External storage is ready for use"
