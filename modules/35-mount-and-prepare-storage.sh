#!/usr/bin/env bash
# Module 35: Partition + Format external drive (dynamic, non-destructive when possible)

set -Eeuo pipefail

if [[ -n "${LOG_LIB:-}" && -f "$LOG_LIB" ]]; then source "$LOG_LIB"; else
    log::info(){ echo "[INFO] $*"; }
    log::warn(){ echo "[WARN] $*"; }
    log::error(){ echo "[ERROR] $*"; }
    log::success(){ echo "[SUCCESS] $*"; }
    log::section(){ echo; echo "=== $* ==="; echo; }
fi

log::section "Partitioning & Formatting External Drive (Dynamic)"

STORAGE_ENV="/tmp/storage.env"
source "$STORAGE_ENV"

if [[ -z "${DEVICE:-}" ]]; then
    log::error "DEVICE not found in $STORAGE_ENV"
    exit 1
fi

log::info "Using device: $DEVICE"

# Detect first partition on the device
PARTITION="$(lsblk -ndo NAME,TYPE "$DEVICE" | awk '$2=="part"{print "/dev/"$1; exit}')"

if [[ -n "$PARTITION" ]]; then
    # Partition exists — check filesystem
    if blkid "$PARTITION" | grep -q ext4; then
        log::info "Found existing ext4 partition: $PARTITION — reusing as storage."
        echo "PARTITION=$PARTITION" >> "$STORAGE_ENV"
        log::success "Partition + Format step skipped (already suitable)."
        exit 0
    else
        log::warn "Partition $PARTITION exists but is not ext4 — would require destructive format."
        # You can choose to fail here instead of auto-wiping:
        log::error "Refusing to auto-wipe non-ext4 partition. Please back up and clean the disk."
        exit 1
    fi
fi

# No partition found — destructive path (only if truly empty)
log::info "No partition found — creating GPT + ext4 partition"

parted -s "$DEVICE" mklabel gpt
parted -s "$DEVICE" mkpart primary ext4 0% 100%
sleep 2

PARTITION="$(lsblk -ndo NAME,TYPE "$DEVICE" | awk '$2=="part"{print "/dev/"$1; exit}')"

if [[ -z "$PARTITION" ]]; then
    log::error "Partition creation failed."
    exit 1
fi

log::success "Created partition: $PARTITION"

log::info "Formatting $PARTITION as ext4"
mkfs.ext4 -F "$PARTITION"

echo "PARTITION=$PARTITION" >> "$STORAGE_ENV"
log::success "Partition + Format complete."
