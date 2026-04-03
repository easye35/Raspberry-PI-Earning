#!/usr/bin/env bash
set -euo pipefail

source "$LOG_LIB"

log::section "Preparing External Storage for Appliance"

DEVICE="/dev/sda1"
MOUNTPOINT="/mnt/appliance-data"

detect_existing_mounts() {
    log::step "Checking for auto-mounted HDD"

    local auto
    auto=$(mount | grep "$DEVICE" | awk '{print $3}' || true)

    if [[ -n "$auto" && "$auto" != "$MOUNTPOINT" ]]; then
        log::warn "Drive is auto-mounted at: $auto"
        log::spinner "Unmounting auto-mount" sudo umount "$auto"
    else
        log::substep "No conflicting auto-mounts."
    fi
}

create_mountpoint() {
    log::step "Ensuring mountpoint exists"
    sudo mkdir -p "$MOUNTPOINT"
    log::ok "Mountpoint ready: $MOUNTPOINT"
}

mount_drive() {
    log::step "Mounting HDD to appliance mountpoint"

    log::spinner "Mounting $DEVICE" sudo mount "$DEVICE" "$MOUNTPOINT"

    if mount | grep -q "$MOUNTPOINT"; then
        log::ok "Drive mounted successfully."
    else
        log::die "Failed to mount HDD."
    fi
}

write_fstab() {
    log::step "Writing persistent fstab entry"

    local uuid
    uuid=$(blkid -s UUID -o value "$DEVICE")

    log::substep "UUID: $uuid"

    # Remove old entries
    sudo sed -i '/appliance-data/d' /etc/fstab

    # Add new entry
    echo "UUID=$uuid $MOUNTPOINT ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab >/dev/null

    log::ok "fstab updated."
}

prepare_directories() {
    log::step "Preparing directory structure on HDD"

    sudo mkdir -p "$MOUNTPOINT/docker"
    sudo mkdir -p "$MOUNTPOINT/logs"

    log::ok "Directories ready."
}

main() {
    detect_existing_mounts
    create_mountpoint
    mount_drive
    write_fstab
    prepare_directories

    log::success_block "HDD prepared and mounted at $MOUNTPOINT"
}

main "$@"
