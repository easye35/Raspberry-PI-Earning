#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# Load Logging Library FIRST (so all modules have logging)
###############################################################################

LOG_LIB="$(dirname "$0")/logging.sh"

if [[ -f "$LOG_LIB" ]]; then
    source "$LOG_LIB"
else
    echo "[ERROR] Logging library not found at: $LOG_LIB"
    exit 1
fi

###############################################################################
# Utility Functions Shared Across All Modules
###############################################################################

utils::require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log::fail "This module must be run as root."
    fi
}

utils::check_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log::fail "Required command not found: $cmd"
    fi
}

utils::pause() {
    local msg="${1:-Press Enter to continue...}"
    read -rp "$msg"
}

utils::file_exists() {
    local file="$1"
    [[ -f "$file" ]]
}

utils::dir_exists() {
    local dir="$1"
    [[ -d "$dir" ]]
}

utils::ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi
}

utils::run_or_fail() {
    local description="$1"
    shift
    if "$@"; then
        log::ok "$description"
    else
        log::fail "$description failed"
    fi
}

###############################################################################
# Storage Helpers
###############################################################################

utils::get_partition() {
    lsblk -no NAME "/dev/sda" | grep -E "^sda[0-9]+$" | head -n 1 || true
}

utils::is_mounted() {
    local part="$1"
    lsblk -no MOUNTPOINT "$part" 2>/dev/null | grep -q "/" || return 1
}

utils::unmount_if_mounted() {
    local part="$1"
    if utils::is_mounted "$part"; then
        local mp
        mp="$(lsblk -no MOUNTPOINT "$part")"
        log::warn "Unmounting $part from $mp"
        umount "$part"
    fi
}

###############################################################################
# End of utils.sh
###############################################################################
