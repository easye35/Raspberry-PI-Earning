#!/usr/bin/env bash
set -euo pipefail

source "$LOG_LIB"

log::section "Detecting External Storage"

detect_usb_disks() {
    log::step "Scanning for USB storage devices"

    lsblk -J -o NAME,MODEL,TYPE,SIZE,MOUNTPOINT | jq -r '
        .blockdevices[]
        | select(.type=="disk")
        | select(.model != null and (.model | test("SD|MMC") | not))
        | .name
    '
}

validate_drive() {
    local disk="$1"

    log::step "Validating drive /dev/$disk"

    if mount | grep -q "/dev/$disk"; then
        log::fail "Drive /dev/$disk is mounted — cannot use."
        return 1
    fi

    if [[ "$disk" == "mmcblk0" ]]; then
        log::fail "Drive is the SD card — skipping."
        return 1
    fi

    log::ok "Drive /dev/$disk is valid."
}

main() {
    local disks
    disks=$(detect_usb_disks)

    if [[ -z "$disks" ]]; then
        log::warn "No external HDD/SSD detected."
        echo "STORAGE_AVAILABLE=0" > /tmp/storage.env
        return 0
    fi

    local selected
    selected=$(echo "$disks" | head -n 1)

    log::substep "Selected drive: /dev/$selected"

    validate_drive "$selected" || log::die "Storage validation failed."

    {
        echo "STORAGE_AVAILABLE=1"
        echo "STORAGE_DEVICE=/dev/$selected"
    } > /tmp/storage.env

    log::success_block "External storage detected and validated."
}

main "$@"
