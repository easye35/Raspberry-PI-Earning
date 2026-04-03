#!/usr/bin/env bash
set -Eeuo pipefail

# Resolve module directory
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load logging
source "$MODULE_DIR/logging.sh"

# Load utils
source "$MODULE_DIR/utils.sh"
log::section "Detecting External Storage"

STORAGE_ENV="/tmp/storage.env"
rm -f "$STORAGE_ENV"; touch "$STORAGE_ENV"; chmod 600 "$STORAGE_ENV"

log::info "[Step] Scanning for USB storage devices"

CANDIDATES="$(lsblk -ndo NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}' | grep -E '^/dev/sd' || true)"

if [[ -z "$CANDIDATES" ]]; then
    log::error "No /dev/sdX disks detected."
    exit 1
fi

DEVICE="$(echo "$CANDIDATES" | head -n 1)"
log::info "Detected disk: $DEVICE"

echo "DEVICE=$DEVICE" >> "$STORAGE_ENV"

log::success "Storage detection complete."
