#!/usr/bin/env bash
set -euo pipefail

# Resolve directories
MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MODULES_DIR/.." && pwd)"

# Load shared libraries
source "$ROOT_DIR/lib/logging.sh"
source "$ROOT_DIR/lib/utils.sh"

log::section "Detecting External Storage"

main() {
    log::step "Scanning for USB storage devices"

    # Find first USB partition (sda1, sdb1, etc)
    local part
    part=$(lsblk -p -o NAME,TYPE | awk '$2=="part" && $1 ~ "/dev/sd"{print $1; exit}')

    if [[ -z "$part" ]]; then
        log::warn "No external HDD/SSD detected."
        echo "STORAGE_AVAILABLE=0" > /tmp/storage.env
        return 0
    fi

    log::substep "Detected partition: $part"

    # Validate that it's not the SD card
    if [[ "$part" == *"mmcblk0"* ]]; then
        log::die "Detected SD card instead of USB drive."
    fi

    # Ensure it's not mounted somewhere unexpected
    if mount | grep -q "$part"; then
        log::warn "Drive is currently mounted — will unmount in next module."
    fi

    {
        echo "STORAGE_AVAILABLE=1"
        echo "STORAGE_DEVICE=$part"
    } > /tmp/storage.env

    log::success_block "External storage detected: $part"
}

main "$@"
