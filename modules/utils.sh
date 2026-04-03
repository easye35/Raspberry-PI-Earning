#!/usr/bin/env bash
# Utility module (appliance‑grade, safe under set -euo pipefail)

# ---------------------------------------------------------
# Safe mkdir
# ---------------------------------------------------------
utils::mkdir_safe() {
    local dir="$1"
    [[ -d "$dir" ]] || mkdir -p "$dir"
}

# ---------------------------------------------------------
# Initialization (SAFE: no exits under set -euo pipefail)
# ---------------------------------------------------------
utils::init() {
    log::info "Initializing utility module…"

    # Dependency check — NEVER fail the installer
    local cmds=(curl wget jq git)
    for cmd in "${cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log::warn "Missing dependency: $cmd"
        fi
    done

    log::ok "Utilities initialized."
}

# ---------------------------------------------------------
# Require root (safe)
# ---------------------------------------------------------
utils::require_root() {
    if [[ ${EUID:-999} -ne 0 ]]; then
        log::die "This action requires root privileges (sudo)."
    fi
}

# ---------------------------------------------------------
# Confirmation prompt
# ---------------------------------------------------------
utils::confirm() {
    local prompt="$1"
    read -r -p "$prompt [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}
