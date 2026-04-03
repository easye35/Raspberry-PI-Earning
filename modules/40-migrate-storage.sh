#!/usr/bin/env bash
set -euo pipefail

source "$LOG_LIB"

log::section "Migrating Appliance Data to External Storage"

load_env() {
    if [[ ! -f /tmp/storage.env ]]; then
        log::die "Missing storage detection info — aborting."
    fi
    source /tmp/storage.env
}

format_drive() {
    local dev="$1"
    log::step "Formatting $dev as ext4"

    log::spinner "Formatting drive" mkfs.ext4 -F "$dev"
}

mount_drive() {
    local dev="$1"

    log::step "Mounting drive at /mnt/appliance-data"
    mkdir -p /mnt/appliance-data

    local uuid
    uuid=$(blkid -s UUID -o value "$dev")

    log::substep "UUID: $uuid"

    mount "$dev" /mnt/appliance-data

    log::substep "Updating /etc/fstab"
    echo "UUID=$uuid /mnt/appliance-data ext4 defaults,noatime 0 2" >> /etc/fstab
}

migrate_docker() {
    log::step "Migrating Docker data"

    log::spinner "Stopping Docker" systemctl stop docker

    mkdir -p /mnt/appliance-data/docker

    log::spinner "Copying Docker data" rsync -aHAX /var/lib/docker/ /mnt/appliance-data/docker/

    log::substep "Updating Docker daemon.json"
    mkdir -p /etc/docker
    cat >/etc/docker/daemon.json <<EOF
{
  "data-root": "/mnt/appliance-data/docker"
}
EOF

    log::spinner "Restarting Docker" systemctl start docker
}

migrate_diagnostics() {
    log::step "Migrating diagnostics logs"

    mkdir -p /mnt/appliance-data/logs
    log::spinner "Copying logs" rsync -a /var/log/appliance/ /mnt/appliance-data/logs/
}

main() {
    load_env

    if [[ "$STORAGE_AVAILABLE" -eq 0 ]]; then
        log::warn "No storage available — skipping migration."
        return 0
    fi

    local dev="$STORAGE_DEVICE"

    log::title "Beginning migration to $dev"

    format_drive "$dev"
    mount_drive "$dev"
    migrate_docker
    migrate_diagnostics

    log::success_block "Storage migration completed successfully."
}

main "$@"
