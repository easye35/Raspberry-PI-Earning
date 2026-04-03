#!/usr/bin/env bash
set -Eeuo pipefail

# Resolve module directory
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load logging
source "$MODULE_DIR/logging.sh"

# Load utils
source "$MODULE_DIR/utils.sh"

log::section "Power & Hardware Safety Check"

check_pi_model() {
    log::step "Detecting Raspberry Pi model"
    local model
    model=$(tr -d '\0' </proc/device-tree/model)

    log::substep "Detected: $model"

    case "$model" in
        *"Raspberry Pi 4"*)
            log::ok "Pi 4 supports USB boot and adequate USB power."
            ;;
        *"Raspberry Pi 5"*)
            log::ok "Pi 5 detected — excellent USB power and stability."
            ;;
        *)
            log::warn "Older Pi detected — USB HDD/SSD may be unstable."
            return 1
            ;;
    esac
}

check_undervoltage() {
    log::step "Checking for undervoltage conditions"

    local throttled
    throttled=$(vcgencmd get_throttled | awk -F= '{print $2}')

    log::debug "Raw throttled flag: $throttled"

    if [[ "$throttled" == "0x0" ]]; then
        log::ok "No undervoltage detected."
        return 0
    fi

    if (( (throttled & 0x1) != 0 )); then
        log::fail "Undervoltage *currently* detected — unsafe for HDD/SSD."
        return 1
    fi

    if (( (throttled & 0x50000) != 0 )); then
        log::warn "Undervoltage occurred previously — power supply may be unstable."
        return 1
    fi

    return 0
}

main() {
    check_pi_model || log::die "Power check failed due to incompatible Pi model."
    check_undervoltage || log::die "Power check failed due to undervoltage."

    log::success_block "Power system is stable and safe for HDD/SSD installation."
}

main "$@"
