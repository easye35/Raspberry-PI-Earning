#!/usr/bin/env bash
# Module 40: Mount external storage and persist in fstab

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

MOUNT_POINT="/mnt/storage"

mkdir -p "$MOUNT_POINT"

if ! mount | grep -q "$PARTITION"; then
    log::info "Mounting $PARTITION → $MOUNT_POINT"
    mount "$PARTITION" "$MOUNT_POINT"
else
    log::warn "$PARTITION already mounted."
fi

UUID="$(blkid -s UUID -o value "$PARTITION")"

grep -q "$UUID" /etc/fstab || {
    log::info "Adding to /etc/fstab"
    echo "UUID=$UUID  $MOUNT_POINT  ext4  defaults,noatime  0  2" >> /etc/fstab
}

log::success "Mount + fstab complete."
