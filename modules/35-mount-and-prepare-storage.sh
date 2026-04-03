#!/bin/sh
# Module 35: Prepare external drive (dynamic, POSIX-sh, non-destructive)

set -eu

# Simple logging (POSIX-safe)
log_info()    { printf '%s\n' "[INFO] $*"; }
log_warn()    { printf '%s\n' "[WARN] $*"; }
log_error()   { printf '%s\n' "[ERROR] $*"; }
log_success() { printf '%s\n' "[SUCCESS] $*"; }
log_section() { printf '\n=== %s ===\n\n' "$*"; }

log_section "Preparing External Storage (Dynamic)"

STORAGE_ENV="/tmp/storage.env"

if [ ! -f "$STORAGE_ENV" ]; then
    log_error "Missing $STORAGE_ENV"
    exit 1
fi

. "$STORAGE_ENV"

if [ -z "${DEVICE:-}" ]; then
    log_error "DEVICE not found in $STORAGE_ENV"
    exit 1
fi

log_info "Using device: $DEVICE"

###############################################################################
# Detect existing partitions WITHOUT relying on TYPE (BusyBox-safe)
###############################################################################
PARTITION="$(lsblk -n -o NAME "$DEVICE" | grep '^sda[0-9]' | head -n 1 || true)"

if [ -n "$PARTITION" ]; then
    PARTITION="/dev/$PARTITION"
    log_info "Found existing partition: $PARTITION"

    if blkid "$PARTITION" 2>/dev/null | grep -q 'TYPE="ext4"'; then
        log_success "Partition already ext4 — reusing without formatting."
        printf '%s\n' "PARTITION=$PARTITION" >> "$STORAGE_ENV"
        exit 0
    else
        log_error "Partition exists but is not ext4 — refusing destructive format."
        exit 1
    fi
fi

###############################################################################
# If no partition exists, create one (safe path)
###############################################################################
log_info "No partition found — creating GPT + ext4 partition"

parted -s "$DEVICE" mklabel gpt
parted -s "$DEVICE" mkpart primary ext4 0% 100%
sleep 2

PARTITION="$(lsblk -n -o NAME "$DEVICE" | grep '^sda[0-9]' | head -n 1 || true)"

if [ -z "$PARTITION" ]; then
    log_error "Failed to detect new partition on $DEVICE"
    exit 1
fi

PARTITION="/dev/$PARTITION"

log_info "Formatting $PARTITION as ext4"
mkfs.ext4 -F "$PARTITION"

printf '%s\n' "PARTITION=$PARTITION" >> "$STORAGE_ENV"
log_success "Partition + Format complete."
