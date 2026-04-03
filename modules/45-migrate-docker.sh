#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MODULES_DIR/.." && pwd)"

source "$ROOT_DIR/lib/logging.sh"
source "$ROOT_DIR/lib/utils.sh"
source "$ROOT_DIR/lib/docker.sh"

log::section "Migrating Docker to External Storage"

STORAGE_ENV="/tmp/storage.env"

main() {
    if [[ ! -f "$STORAGE_ENV" ]]; then
        log::warn "No storage env file found. Skipping Docker migration."
        return 0
    fi

    # shellcheck disable=SC1090
    source "$STORAGE_ENV"

    if [[ "${STORAGE_AVAILABLE:-0}" -ne 1 ]]; then
        log::warn "No external storage available. Skipping Docker migration."
        return 0
    fi

    local dev="${STORAGE_DEVICE:?}"
    local mount_point="${STORAGE_MOUNT_POINT:-/mnt/external-storage}"
    local docker_dir="${mount_point}/docker"
    local docker_service="/etc/docker/daemon.json"

    log::step "Ensuring Docker is stopped"
    docker::stop || true

    log::step "Preparing Docker directory on external storage: $docker_dir"
    sudo mkdir -p "$docker_dir"
    sudo chown root:root "$docker_dir"

    local current_root
    current_root=$(docker::get_data_root || echo "/var/lib/docker")

    log::info "Current Docker data-root: $current_root"
    log::info "Target Docker data-root:  $docker_dir"

    if [[ -d "$current_root" && ! -L "$current_root" ]]; then
        log::step "Migrating existing Docker data to external storage"
        sudo rsync -aHAX --delete "$current_root"/ "$docker_dir"/
        log::ok "Docker data migrated to $docker_dir"
    else
        log::info "No existing Docker data to migrate or already symlinked."
    fi

    log::step "Updating Docker daemon configuration"

    sudo mkdir -p "$(dirname "$docker_service")"
    sudo bash -c "cat > '$docker_service' <<EOF
{
  \"data-root\": \"$docker_dir\"
}
EOF"

    log::ok "Docker daemon.json updated."

    log::step "Restarting Docker with new data-root"
    docker::restart

    log::success_block "Docker is now using external storage at: $docker_dir"
}

main "$@"
