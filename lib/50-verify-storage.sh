
#!/usr/bin/env bash
set -euo pipefail

source "$LOG_LIB"

log::section "Storage Verification"

verify_mount() {
    log::step "Checking HDD mount"

    if mount | grep -q "/mnt/appliance-data"; then
        log::ok "HDD mounted at /mnt/appliance-data"
    else
        log::fail "HDD NOT mounted."
    fi
}

verify_docker_root() {
    log::step "Checking Docker root directory"

    local root
    root=$(docker info 2>/dev/null | grep "Docker Root Dir" | awk -F': ' '{print $2}' || true)

    log::substep "Docker Root Dir: $root"

    if [[ "$root" == "/mnt/appliance-data/docker" ]]; then
        log::ok "Docker is using the HDD ✔"
    else
        log::fail "Docker is NOT using the HDD."
    fi
}

main() {
    verify_mount
    verify_docker_root

    log::success_block "Storage verification complete."
}

main "$@"
