#!/usr/bin/env bash
# Diagnostics module (appliance‑grade)
# Requires: lib/logging.sh, lib/colors.sh, utils.sh, docker.sh

MODULE_DIR="$(dirname "${BASH_SOURCE[0]}")"
LIB_DIR="${MODULE_DIR}/../lib"

# shellcheck source=../lib/logging.sh
source "${LIB_DIR}/logging.sh"

###############################################
# SECTION: Raspberry Pi Power Diagnostics
###############################################

diagnostics::_pi_power_status() {
    log::section "Raspberry Pi Power & Thermal Health"

    if ! utils::cmd_exists vcgencmd; then
        log::warn "vcgencmd not available — skipping Pi‑specific checks."
        return
    fi

    local throttled
    throttled=$(vcgencmd get_throttled | awk -F= '{print $2}')

    log::info "Raw throttled flags: $throttled"

    # Bitmask reference:
    # 0x1  Under-voltage detected
    # 0x2  Arm frequency capped
    # 0x4  Currently throttled
    # 0x10000 Under-voltage has occurred
    # 0x20000 Arm frequency capping has occurred
    # 0x40000 Throttling has occurred

    (( throttled & 0x1 ))       && log::fail "⚡ UNDER‑VOLTAGE DETECTED (bad power supply)" || log::ok "No active undervoltage."
    (( throttled & 0x2 ))       && log::warn "CPU frequency capped (power/thermal)" || log::ok "CPU frequency normal."
    (( throttled & 0x4 ))       && log::warn "System is currently throttled" || log::ok "No active throttling."

    (( throttled & 0x10000 ))   && log::warn "Undervoltage occurred previously" || true
    (( throttled & 0x20000 ))   && log::warn "Frequency capping occurred previously" || true
    (( throttled & 0x40000 ))   && log::warn "Throttling occurred previously" || true

    # Temperature
    local temp
    temp=$(vcgencmd measure_temp | grep -oP '\d+\.\d+')

    log::info "Temperature: ${temp}°C"

    if (( $(echo "$temp > 80" | bc -l) )); then
        log::warn "High temperature — consider better cooling."
    else
        log::ok "Temperature within safe range."
    fi
}

###############################################
# SECTION: System Diagnostics
###############################################

diagnostics::_system_info() {
    log::section "System Information"

    log::info "Hostname: $(hostname)"
    log::info "Architecture: $(uname -m)"
    log::info "Kernel: $(uname -r)"
}

diagnostics::_resource_usage() {
    log::section "CPU, RAM, Disk Usage"

    log::info "CPU Load:"
    uptime | log::indent

    log::info "Memory:"
    free -h | log::indent

    log::info "Disk:"
    df -h / | log::indent
}

###############################################
# SECTION: Network Diagnostics
###############################################

diagnostics::_network() {
    log::section "Network Diagnostics"

    utils::check_internet || log::warn "Internet check failed."

    log::info "IP Address:"
    hostname -I | log::indent

    log::info "Default Route:"
    ip route | head -n 1 | log::indent
}

###############################################
# SECTION: Docker Diagnostics
###############################################

diagnostics::_docker() {
    log::section "Docker Health"

    if ! utils::cmd_exists docker; then
        log::warn "Docker not installed."
        return
    fi

    docker info | log::indent || log::warn "docker info failed."

    log::info "Running containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}" | log::indent
}

###############################################
# SECTION: Container Diagnostics (Future‑Aware)
###############################################

diagnostics::_registered_containers() {
    log::section "Registered Containers"

    local registry="/var/lib/appliance/containers.list"

    if [[ ! -f "$registry" ]]; then
        log::warn "No container registry found."
        return
    fi

    while IFS='|' read -r name desc; do
        [[ -z "$name" ]] && continue

        log::info "Checking container: $name ($desc)"

        if utils::container_exists "$name"; then
            utils::container_running "$name" \
                && log::ok "$name is running." \
                || log::warn "$name exists but is stopped."

            log::info "Logs:"
            utils::container_logs "$name"
        else
            log::warn "$name is not installed."
        fi
    done < "$registry"
}

###############################################
# SECTION: Public API
###############################################

diagnostics::run() {
    log::title "Running Full System Diagnostics"

    diagnostics::_pi_power_status
    diagnostics::_system_info
    diagnostics::_resource_usage
    diagnostics::_network
    diagnostics::_docker
    diagnostics::_registered_containers

    log::ok "Diagnostics complete."
}
