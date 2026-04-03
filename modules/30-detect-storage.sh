#!/usr/bin/env bash
set -euo pipefail

# Resolve directories
MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MODULES_DIR/.." && pwd)"

# Load shared libraries
source "$ROOT_DIR/lib/logging.sh"
source "$ROOT_DIR/lib/utils.sh"

log::section "Detecting External Storage"

# ---------------------------------------------------------
# Auto‑Unmount Function (new)
# ---------------------------------------------------------
auto_unmount_drive() {
    local dev="$1"

    # Find all mountpoints for this device (system + user-session)
    mapfile -t MOUNTS < <(lsblk -nrpo MOUNTPOINT "$dev" | grep -v '^$')

    if [[ ${#MOUNTS[@]} -eq 0 ]]; then
        log::ok "Drive is not mounted."
        return 0
    fi

    log::warn "Drive is mounted at:"
    for m in "${MOUNTS[@]}"; do
        echo "   → $m"
    done

    log::info "Attempting safe auto‑unmount..."

    for m in "${MOUNTS[@]}"; do
        # Try udisks2 first (desktop auto-mount)
        if command -v udisksctl >/dev/null 2>&1; then
            if udisksctl unmount -b "$dev" >/dev/null 2>&1; then
                log::ok "Unmounted via udisksctl: $m"
                continue
            fi
        fi

        # Fallback to sudo umount
        if sudo umount "$m" >/dev/null 2>&1; then
            log::ok "Unmounted: $m"
        else
            log::error "Failed to unmount $m"
            return 1
        fi
    done

    log::ok "Drive fully unmounted and ready."
}

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

    # NEW: Auto‑unmount here instead of deferring
    log::info "Checking mount status..."
    auto_unmount_drive "$part"

    {
        echo "STORAGE_AVAILABLE=1"
        echo "STORAGE_DEVICE=$part"
    } > /tmp/storage.env

    log::success_block "External storage ready: $part"
}

main "$@"
