#!/usr/bin/env bash
# Module 30: Detect external storage and persist selection

set -Eeuo pipefail

# Load logging library if available
if [[ -n "${LOG_LIB:-}" && -f "$LOG_LIB" ]]; then
    # shellcheck source=/dev/null
    source "$LOG_LIB"
else
    echo "[WARN] LOG_LIB not set or logging.sh missing — using fallback logger"
    log::info()    { echo "[INFO] $*"; }
    log::warn()    { echo "[WARN] $*"; }
    log::error()   { echo "[ERROR] $*"; }
    log::success() { echo "[SUCCESS] $*"; }
    log::section() { echo; echo "▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒"; echo "  $*"; echo "▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒"; echo; }
fi

log::section "Detecting External Storage"

STORAGE_ENV="/tmp/storage.env"

# Always recreate storage env file with safe permissions
rm -f "$STORAGE_ENV"
touch "$STORAGE_ENV"
chmod 600 "$STORAGE_ENV"

log::info "[Step] Scanning for USB storage devices"

# List block devices, filter for /dev/sdX (USB/SATA) but ignore root FS if on USB
# You can refine this later; for now we assume /dev/sda is the external drive.
DEVICE=""
PARTITION=""

# Prefer lsblk JSON if available
if command -v lsblk >/dev/null 2>&1; then
    # Get all /dev/sdX devices
    MAPFILE -t CANDIDATES < <(lsblk -ndo NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}' | grep -E '^/dev/sd')
else
    CANDIDATES=()
fi

if [[ "${#CANDIDATES[@]}" -eq 0 ]]; then
    log::error "No /dev/sdX disks detected. Plug in your HDD/SSD and rerun the installer."
    exit 1
fi

# For now, pick the first candidate as the external device
DEVICE="${CANDIDATES[0]}"

# Find first partition on that device (e.g., /dev/sda1)
if lsblk -ndo NAME,TYPE "$DEVICE" | awk '$2=="part"{exit 0} END{exit 1}'; then
    PARTITION="/dev/$(lsblk -ndo NAME,TYPE "$DEVICE" | awk '$2=="part"{print $1; exit}')"
else
    log::error "No partition found on $DEVICE. You may need to partition/format it first."
    exit 1
fi

echo "    → Detected partition: $PARTITION"

log::info "[INFO] Checking mount status..."

# Check if partition is already mounted
if findmnt -rn "$PARTITION" >/dev/null 2>&1; then
    MOUNT_POINT="$(findmnt -rn -o TARGET "$PARTITION")"
    log::warn "[WARN] $PARTITION is already mounted at $MOUNT_POINT"
else
    log::success "[OK] Drive is not mounted."
fi

# Persist selection to /tmp/storage.env
{
    echo "DEVICE=$DEVICE"
    echo "PARTITION=$PARTITION"
} >> "$STORAGE_ENV"

log::success "Storage detection complete."
log::info "Persisted to $STORAGE_ENV:"
cat "$STORAGE_ENV"
