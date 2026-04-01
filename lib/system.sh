#!/usr/bin/env bash
# System module (appliance‑grade)
# Requires: lib/logging.sh, lib/colors.sh

MODULE_DIR="$(dirname "${BASH_SOURCE[0]}")"
LIB_DIR="${MODULE_DIR}/../lib"

# shellcheck source=../lib/logging.sh
source "${LIB_DIR}/logging.sh"

###############################################
# SECTION: Internal helpers
###############################################

system::_require_root() {
    if [[ $EUID -ne 0 ]]; then
        log::die "This installer must be run as root (sudo)."
    fi
}

system::_detect_arch() {
    ARCH=$(uname -m)
    case "$ARCH" in
        armv7l|armhf)   SYSTEM_ARCH="arm32" ;;
        aarch64|arm64)  SYSTEM_ARCH="arm64" ;;
        x86_64)         SYSTEM_ARCH="amd64" ;;
        *)              log::die "Unsupported architecture: $ARCH" ;;
    esac
}

system::_check_disk() {
    local required_mb=2000
    local available_mb
    available_mb=$(df -m / | awk 'NR==2 {print $4}')

    if (( available_mb < required_mb )); then
        log::warn "Low disk space: ${available_mb}MB available, ${required_mb}MB required."
    else
        log::ok "Disk space OK (${available_mb}MB available)."
    fi
}

system::_ensure_swap() {
    local min_swap_mb=1024
    local current_swap_mb
    current_swap_mb=$(free -m | awk '/Swap/ {print $2}')

    if (( current_swap_mb < min_swap_mb )); then
        log::warn "Swap is low (${current_swap_mb}MB). Creating 1GB swapfile…"

        fallocate -l 1G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=1024
        chmod 600 /swapfile
        mkswap /swapfile >/dev/null
        swapon /swapfile

        if ! grep -q "/swapfile" /etc/fstab; then
            echo "/swapfile none swap sw 0 0" >> /etc/fstab
        fi

        log::ok "Swapfile created."
    else
        log::ok "Swap OK (${current_swap_mb}MB)."
    fi
}

system::_kernel_tuning() {
    log::info "Applying kernel tuning (safe defaults)…"

    sysctl -w vm.swappiness=10 >/dev/null
    sysctl -w fs.inotify.max_user_watches=524288 >/dev/null

    log::ok "Kernel tuning applied."
}

###############################################
# SECTION: Public API
###############################################

system::preflight() {
    log::section "System Preflight Checks"

    system::_require_root
    system::_detect_arch
    system::_check_disk

    log::info "Architecture detected: ${SYSTEM_ARCH}"
}

system::update() {
    log::section "Updating System Packages"

    apt-get update -y || log::die "apt-get update failed."
    apt-get upgrade -y || log::die "apt-get upgrade failed."

    log::ok "System updated."
}

system::install_dependencies() {
    log::section "Installing Dependencies"

    local pkgs=(
        curl wget git jq ca-certificates
        apt-transport-https software-properties-common
    )

    apt-get install -y "${pkgs[@]}" || log::die "Failed to install dependencies."

    log::ok "Dependencies installed."
}

system::optimize() {
    log::section "System Optimization"

    system::_ensure_swap
    system::_kernel_tuning

    log::ok "System optimized."
}

###############################################
# SECTION: Future‑container‑friendly hooks
###############################################

# This is the key to making your system easily extendable.
# Any new container module can register itself here.

system::register_container() {
    local name="$1"
    local description="$2"

    printf "%s|%s\n" "$name" "$description" >> /var/lib/appliance/containers.list
}

system::init_container_registry() {
    mkdir -p /var/lib/appliance
    : > /var/lib/appliance/containers.list
    log::ok "Container registry initialized."
}

###############################################
# SECTION: Main entrypoint
###############################################

system::init() {
    log::title "Initializing System Module"

    system::preflight
    system::update
    system::install_dependencies
    system::optimize
    system::init_container_registry

    log::ok "System module complete."
}
