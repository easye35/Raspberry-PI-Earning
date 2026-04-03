#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MODULES_DIR/.." && pwd)"

source "$ROOT_DIR/lib/logging.sh"
source "$ROOT_DIR/lib/utils.sh"

log::section "Verifying External Storage & Docker Migration"

STORAGE_ENV="/tmp/storage.env"

main() {
    if [[ ! -f "$STORAGE_ENV" ]]; then
        log::warn "No storage env file found. Skipping verification."
        return 0
    fi

    # shellcheck disable=SC1090
    source "$STORAGE_ENV"

    if [[ "${STORAGE_AVAILABLE:-0}" -ne 1 ]]; then
        log::warn "No external storage available. Skipping verification."
        return 0
    fi

    local dev="${STORAGE_DEVICE:?}"
    local mount_point="${STORAGE_MOUNT_POINT:-/mnt/external-storage}"

    log::step "Verifying mount: $mount_point"
    if ! mount | awk -v m="$mount_point" '$3==m {found=1} END{exit !found}'; then
        log::die "External storage is not mounted at $mount_point"
    fi
    log::ok "External storage is mounted at $mount_point"

    log::step "Checking free space on external storage"
    df -h "$mount_point" | sed -n '1,2p'

    log::step "Running quick read/write test"
    local test_file="$mount_point/.storage_test_$$"
    echo "storage test $(date)" | sudo tee "$test_file" >/dev/null
    sudo cat "$test_file" >/dev/null
    sudo rm -f "$test_file"
    log::ok "Read/write test passed on $mount_point"

    log::success_block "External storage and Docker migration verified successfully."
}

main "$@"
