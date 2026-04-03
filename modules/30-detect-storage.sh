#!/usr/bin/env bash
# Module 30: Detect external storage and persist selection (POSIX-safe)

set -Eeuo pipefail

# Load logging library if available
if [[ -n "${LOG_LIB:-}" && -f "$LOG_LIB" ]]; then
    # shellcheck source=/dev/null
    source "$LOG_LIB"
else
    echo "[WARN] LOG_LIB missing — using fallback logger"
    log::info()    { echo "[INFO] $*"; }
    log::warn()    { echo "[WARN] $*"; }
    log::error()   { echo "[ERROR] $*"; }
    log::success() { echo "[SUCCESS] $*"; }
    log::section() { echo; echo "=== $* ==="; echo; }
fi

log::section "Detecting External Storage"

STORAGE_ENV="/tmp/storage.env"

# Always recreate storage env file with safe permissions
rm -f "$STORAGE_ENV"
touch "$STORAGE_ENV"
chmod 600 "$STORAGE_ENV"

log::info "[Step] Scanning for USB storage devices"

###############################################################################
# DEVICE DETECTION (POSIX-safe)
###############################################################################

# Find all /dev/sdX disks (ignore partitions)
CANDIDATES="$(lsblk -ndo NAME,TYPE 2>/dev/null | awk '$2=="disk"{print "/dev/"$1}' | grep -E '^/dev/sd' || true)"

if [[ -z "$CANDIDATES" ]]; then
    log::error "No /dev/sdX disks detected. Plug in your HDD/SSD and rerun."
    exit 1
fi

# Pick the first detected disk
DEVICE="$(echo "$CANDIDATES" | head -n 1)"

log::info "Detected disk: $DEVICE"

###############################################################################
# PARTITION DETECTION (POSIX-safe)
###############################################################################

# Find first partition on the device
PARTITION="$(lsblk -ndo NAME,TYPE "$DEVICE" 2>/dev/null | awk '$2=="part"{print "/dev/"$1; exit}')"

if [[ -z "$PARTITION" ]]; then
    log::error "No partitions found on $DEVICE. You may need to format it first."
    exit 1
fi

echo "    → Detected partition: $PARTITION"

###############################################################################
# MOUNT CHECK
###############################################################################

log::info "[INFO] Checking mount status..."

if findmnt -rn "$PARTITION" >/dev/null 2>&1; then
    MOUNT_POINT="$(findmnt -rn -o TARGET "$PARTITION")"
    log::warn "[WARN] $PARTITION is already mounted at $MOUNT_POINT"
else
    log::success "[OK] Drive is not mounted."
fi

###############################################################################
# WRITE RESULTS TO /tmp/storage.env
###############################################################################

{
    echo "DEVICE=$DEVICE"
    echo "PARTITION=$PARTITION"
} >> "$STORAGE_ENV"

log::success "Storage detection complete."
log::info "Persisted to $STORAGE_ENV:"
cat "$STORAGE_ENV"
