#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MODULES_DIR/.." && pwd)"

source "$ROOT_DIR/lib/logging.sh"
source "$ROOT_DIR/lib/utils.sh"

log::section "Mounting and Preparing External Storage"

STORAGE_ENV="/tmp/storage.env"

main() {
    if [[ ! -f "$STORAGE_ENV" ]]; then
        log::warn "No storage env file found. Skipping storage preparation."
        return 0
    fi

    # shellcheck disable=SC1090
    source "$STORAGE_ENV"

    if [[ "${STORAGE_AVAILABLE:-0}" -ne 1 ]]; then
        log::warn "No external storage available. Skipping mount and prepare."
        return 0
    fi

    local dev="${STORAGE_DEVICE:?}"
    local mount_point="/mnt/external-storage"

    log::step "Preparing mount point: $mount_point"
    sudo mkdir -p "$mount_point"

    # Check if filesystem exists
    local fstype
    fstype=$(blkid -o value -s TYPE "$dev" || true)

    if [[ -z "$fstype" ]]; then
        log::warn "No filesystem detected on $dev — creating ext4 filesystem."
        sudo mkfs.ext4 -F "$dev"
        log::ok "Filesystem created on $dev"
    else
        log::info "Detected filesystem on $dev: $fstype"
    fi

    # Ensure not already mounted
    if mount | awk -v m="$mount_point" '$3==m {found=1} END{exit !found}'; then
        log::warn "Mount point $mount_point already in use. Unmounting."
        sudo umount "$mount_point"
    fi

    log::step "Mounting $dev to $mount_point"
    sudo mount "$dev" "$mount_point"

    log::ok "Mounted $dev at $mount_point"

    {
        echo "STORAGE_AVAILABLE=1"
        echo "STORAGE_DEVICE=$dev"
        echo "STORAGE_MOUNT_POINT=$mount_point"
    } > "$STORAGE_ENV"

    log::success_block "External storage mounted and ready at: $mount_point"
}

main "$@"
