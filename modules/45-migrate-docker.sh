#!/usr/bin/env bash
set -euo pipefail

source "$LOG_LIB"

MOUNTPOINT="/mnt/appliance-data"
NEW_ROOT="$MOUNTPOINT/docker"
OLD_ROOT="/var/lib/docker"

log::section "Migrating Docker to External Storage"

stop_docker() {
    log::step "Stopping Docker"
    log::spinner "Stopping Docker service" sudo systemctl stop docker || true

    if pgrep dockerd >/dev/null; then
        log::warn "dockerd still running — forcing kill"
        sudo killall dockerd || true
    fi
}

migrate_data() {
    log::step "Migrating Docker data"

    if [[ -d "$OLD_ROOT" ]]; then
        log::spinner "Copying Docker data" sudo rsync -aHAX "$OLD_ROOT/" "$NEW_ROOT/"
    else
        log::warn "Old Docker root not found — skipping copy."
    fi
}

write_daemon_json() {
    log::step "Updating Docker daemon.json"

    sudo mkdir -p /etc/docker

    cat <<EOF | sudo tee /etc/docker/daemon.json >/dev/null
{
  "data-root": "$NEW_ROOT"
}
EOF

    log::ok "daemon.json updated."
}

start_docker() {
    log::step "Restarting Docker"
    log::spinner "Starting Docker service" sudo systemctl start docker
}

verify() {
    log::step "Verifying Docker root"

    local root
    root=$(docker info 2>/dev/null | grep "Docker Root Dir" | awk -F': ' '{print $2}' || true)

    if [[ "$root" == "$NEW_ROOT" ]]; then
        log::success_block "Docker is now using the HDD ✔"
    else
        log::fail "Docker is still using: $root"
        log::die "Migration failed."
    fi
}

main() {
    stop_docker
    migrate_data
    write_daemon_json
    start_docker
    verify
}

main "$@"
