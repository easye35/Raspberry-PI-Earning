#!/usr/bin/env bash
# Module 40: Mount external storage (reuse existing mount if present)

set -Eeuo pipefail

if [[ -n "${LOG_LIB:-}" && -f "$LOG_LIB" ]]; then source "$LOG_LIB"; else
    log::info(){ echo "[INFO] $*"; }
    log::warn(){ echo "[WARN] $*"; }
    log::error(){ echo "[ERROR] $*"; }
    log::success(){ echo "[SUCCESS] $*"; }
    log::section(){ echo; echo "=== $* ==="; echo; }
fi

log::section "Mounting External Storage"

STORAGE_ENV="/tmp/storage.env"
source "$STORAGE_ENV"

if [[ -z "${PARTITION:-}" ]]; then
    log::error "PARTITION not found in $STORAGE_ENV"
    exit 1
fi

# Check if already mounted
EXISTING_MOUNT="$(findmnt -rn -o TARGET "$PARTITION" 2>/dev/null || true)"

if [[ -n "$EXISTING_MOUNT" ]]; then
    MOUNT_POINT="$EXISTING_MOUNT"
    log::info "Partition $PARTITION already mounted at $MOUNT_POINT — reusing."
else
    MOUNT_POINT="/mnt/storage"
    mkdir -p "$MOUNT_POINT"
    log::info "Mounting $PARTITION → $MOUNT_POINT"
    mount "$PARTITION" "$MOUNT_POINT"
fi

UUID="$(blkid -s UUID -o value "$PARTITION")"

if ! grep -q "$UUID" /etc/fstab; then
    log::info "Adding $PARTITION to /etc/fstab"
    echo "UUID=$UUID  $MOUNT_POINT  ext4  defaults,noatime  0  2" >> /etc/fstab
else
    log::info "UUID already present in /etc/fstab — skipping."
fi

echo "MOUNT_POINT=$MOUNT_POINT" >> "$STORAGE_ENV"

log::success "Mount step complete. Using $MOUNT_POINT as storage root."
