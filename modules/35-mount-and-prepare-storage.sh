#!/usr/bin/env bash
# Module 35: Partition + Format external drive (self‑healing, POSIX-safe)

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

###############################################################################
# STEP 1 — Unmount anything using the disk
###############################################################################
log::info "Ensuring $DEVICE is not mounted"

# Unmount all partitions on the disk
for p in $(lsblk -ndo NAME "$DEVICE" | tail -n +2); do
    PART="/dev/$p"
    if mount | grep -q "$PART"; then
        log::warn "Unmounting $PART"
        umount -f "$PART" || true
    fi
done

###############################################################################
# STEP 2 — Kill processes holding the disk
###############################################################################
log::info "Checking for processes using $DEVICE"

if command -v fuser >/dev/null 2>&1; then
    fuser -km "$DEVICE" 2>/dev/null || true
fi

###############################################################################
# STEP 3 — Wipe signatures (RAID, LVM, old filesystems)
###############################################################################
log::info "Wiping old filesystem signatures"
wipefs -a "$DEVICE" || true

###############################################################################
# STEP 4 — Wipe partition table
###############################################################################
log::info "Wiping partition table"
dd if=/dev/zero of="$DEVICE" bs=1M count=10 status=none || true

sync
sleep 1

###############################################################################
# STEP 5 — Force kernel to re-scan the disk
###############################################################################
log::info "Rescanning kernel block devices"
partprobe "$DEVICE" 2>/dev/null || true
sleep 1

###############################################################################
# STEP 6 — Create GPT + ext4 partition
###############################################################################
log::info "Creating GPT partition table"
parted -s "$DEVICE" mklabel gpt

log::info "Creating primary ext4 partition"
parted -s "$DEVICE" mkpart primary ext4 0% 100%

sleep 2

###############################################################################
# STEP 7 — Detect new partition
###############################################################################
PARTITION="$(lsblk -ndo NAME,TYPE "$DEVICE" | awk '$2=="part"{print "/dev/"$1; exit}')"

if [[ -z "$PARTITION" ]]; then
    log::error "Partition creation failed."
    exit 1
fi

log::success "Created partition: $PARTITION"

###############################################################################
# STEP 8 — Format ext4
###############################################################################
log::info "Formatting $PARTITION as ext4"
mkfs.ext4 -F "$PARTITION"

echo "PARTITION=$PARTITION" >> "$STORAGE_ENV"

log::success "Partition + Format complete."
