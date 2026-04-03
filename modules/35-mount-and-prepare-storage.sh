#!/usr/bin/env bash
# Module 35: Prepare external drive (dynamic, BusyBox-safe, non-destructive)

set -Eeuo pipefail

# Load logging
if [[ -n "${LOG_LIB:-}" && -f "$LOG_LIB" ]]; then source "$LOG_LIB"; else
    log::info(){ echo "[INFO] $*"; }
    log::warn(){ echo "[WARN] $*"; }
    log::error(){ echo "[ERROR] $*"; }
    log::success(){ echo "[SUCCESS] $*"; }
    log::section(){ echo; echo "=== $* ==="; echo; }
fi

log::section "Preparing External Storage (Dynamic)"

STORAGE_ENV="/tmp/storage.env"
source "$STORAGE_ENV"

if [[ -z "${DEVICE:-}" ]]; then
    log::error "DEVICE not found in $STORAGE_ENV"
    exit 1
fi

log::info "Using device: $DEVICE"

###############################################################################
# Detect existing partitions WITHOUT relying on TYPE (BusyBox-safe)
###############################################################################
PARTITION="$(lsblk -n -o NAME "$DEVICE" | grep -E '^sda[0-9]+' | head -n 1)"

if [[ -n "$PARTITION" ]]; then
    PARTITION="/dev/$PARTITION"
    log::info "Found existing partition: $PARTITION"

    if blkid "$PARTITION" | grep -q ext4; then
        log::success "Partition already ext4 — reusing without formatting."
        echo "PARTITION=$PARTITION" >> "$STORAGE_ENV"
        exit 0
    else
        log::error "Partition exists but is not ext4 — refusing destructive format."
        exit 1
    fi
fi

###############################################################################
# If no partition exists, create one (safe path)
###############################################################################
log::info "No partition found — creating GPT + ext4 partition"

parted -s "$DEVICE" mklabel gpt
parted -s "$DEVICE" mkpart primary ext4 0% 100%
sleep 2

PARTITION="$(lsblk -n -o NAME "$DEVICE" | grep -E '^sda[0-9]+' | head -n 1)"
PARTITION="/dev/$PARTITION"

log::info "Formatting $PARTITION as ext4"
mkfs.ext4 -F "$PARTITION"

echo "PARTITION=$PARTITION" >> "$STORAGE_ENV"
log::success "Partition + Format complete."
