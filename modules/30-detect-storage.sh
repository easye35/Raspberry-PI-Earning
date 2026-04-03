#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MODULES_DIR/.." && pwd)"

source "$ROOT_DIR/lib/logging.sh"

# utils.sh may contain risky code under -euo
set +e
[[ -f "$ROOT_DIR/lib/utils.sh" ]] && source "$ROOT_DIR/lib/utils.sh"
set -e

log::section "Detecting External Storage"

# ---------------------------------------------------------
# Safe lsblk wrapper (prevents silent exits)
# ---------------------------------------------------------
safe_lsblk() {
    lsblk "$@" 2>/dev/null || true
}

# ---------------------------------------------------------
# Auto‑Unmount Function
# ---------------------------------------------------------
auto_unmount_drive() {
    local dev="$1"

    mapfile -t MOUNTS < <(mount | awk -v d="$dev" '$1==d {print $3}')

    if [[ ${#MOUNTS[@]} -eq 0 ]]; then
        log::ok "Drive is not mounted."
        return 0
    fi

    log::warn "Drive is mounted at:"
    printf "   → %s\n" "${MOUNTS[@]}"

    log::info "Attempting safe auto‑unmount..."

    for m in "${MOUNTS[@]}"; do
        if command -v udisksctl >/dev/null 2>&1; then
            if udisksctl unmount -b "$dev" >/dev/null 2>&1; then
                log::ok "Unmounted via udisksctl: $m"
                continue
            fi
        fi

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

    # SAFE: lsblk cannot kill the script now
    local part
    part=$(safe_lsblk -p -o NAME,TYPE | awk '$2=="part" && $1 ~ "/dev/sd"{print $1; exit}')

    if [[ -z "$part" ]]; then
        log::warn "No external HDD/SSD detected."
        echo "STORAGE_AVAILABLE=0" > /tmp/storage.env
        return 0
    fi

    log::substep "Detected partition: $part"

    if [[ "$part" == *"mmcblk0"* ]]; then
        log::die "Detected SD card instead of USB drive."
    fi

    log::info "Checking mount status..."
    auto_unmount_drive "$part"

    {
        echo "STORAGE_AVAILABLE=1"
        echo "STORAGE_DEVICE=$part"
    } > /tmp/storage.env

    log::success_block "External storage ready: $part"
}

main "$@"
