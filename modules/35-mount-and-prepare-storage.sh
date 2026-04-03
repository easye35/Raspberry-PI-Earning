#!/usr/bin/env bash
# Module 35: Partition + Format external drive (POSIX-safe)

set -Eeuo pipefail

# Load logging
if [[ -n "${LOG_LIB:-}" && -f "$LOG_LIB" ]]; then source "$LOG_LIB"; else
    log::info(){ echo "[INFO] $*"; }
    log::warn(){ echo "[WARN] $*"; }
    log::error(){ echo "[ERROR] $*"; }
    log::success(){ echo "[SUCCESS] $*"; }
    log::section(){ echo; echo "=== $* ==="; echo; }
fi

log::section "Partitioning & Formatting External Drive"

STORAGE_ENV="/tmp/storage.env"
source "$STORAGE_ENV"

if [[ -z "${DEVICE:-}" ]]; then
    log::error "DEVICE not found in $STORAGE_ENV"
    exit 1
fi

log::info "Using device: $DEVICE"

# Check if partition already exists
PARTITION="$(lsblk -ndo NAME,TYPE "$DEVICE" | awk '$2=="part"{print "/dev/"$1; exit}')"

if [[ -z "$PARTITION" ]]; then
    log::info "No partition found — creating GPT + ext4 partition"

    parted -s "$DEVICE" mklabel gpt
    parted -s "$DEVICE" mkpart primary ext4 0% 100%

    sleep 2

    PARTITION="$(lsblk -ndo NAME,TYPE "$DEVICE" | awk '$2=="part"{print "/dev/"$1; exit}')"
    if [[ -z "$PARTITION" ]]; then
        log::error "Partition creation failed."
        exit 1
    fi
else
    log::info "Partition already exists: $PARTITION"
fi

# Format if needed
if ! blkid "$PARTITION" | grep -q ext4; then
    log::info "Formatting $PARTITION as ext4"
    mkfs.ext4 -F "$PARTITION"
else
    log::info "$PARTITION already formatted."
fi

echo "PARTITION=$PARTITION" >> "$STORAGE_ENV"

log::success "Partition + Format complete."
