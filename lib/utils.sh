#!/usr/bin/env bash
# Utility module (appliance‑grade)

utils::init() {
    log::info "Initializing utility module…"

    # Ensure required commands exist
    local cmds=(curl wget jq git)
    for cmd in "${cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log::warn "Missing dependency: $cmd"
        fi
    done

    log::ok "Utilities initialized."
}

utils::require_root() {
    if [[ $EUID -ne 0 ]]; then
        log::die "This action requires root privileges (sudo)."
    fi
}

utils::confirm() {
    local prompt="$1"
    read -r -p "$prompt [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}
