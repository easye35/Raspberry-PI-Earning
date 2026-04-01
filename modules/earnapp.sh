#!/usr/bin/env bash
# EarnApp module (appliance‑grade)
# Requires: docker, utils, logging

MODULE_DIR="$(dirname "${BASH_SOURCE[0]}")"
LIB_DIR="${MODULE_DIR}/../lib"

# shellcheck source=../lib/logging.sh

###############################################
# SECTION: Config
###############################################

EARNAPP_CONTAINER="earnapp"
EARNAPP_IMAGE="fearnapp/earnapp:latest"
EARNAPP_DIR="/var/lib/earnapp"
EARNAPP_TOKEN_FILE="${EARNAPP_DIR}/token"

###############################################
# SECTION: Internal helpers
###############################################

earnapp::_ensure_dirs() {
    utils::mkdir_safe "$EARNAPP_DIR"
}

earnapp::_load_token() {
    if [[ -f "$EARNAPP_TOKEN_FILE" ]]; then
        EARNAPP_TOKEN=$(cat "$EARNAPP_TOKEN_FILE")
        return 0
    fi

    log::warn "No EarnApp token found."
    return 1
}

earnapp::_save_token() {
    local token="$1"
    utils::atomic_write "$EARNAPP_TOKEN_FILE" "$token"
    chmod 600 "$EARNAPP_TOKEN_FILE"
}

earnapp::_prompt_token() {
    log::info "EarnApp requires a device token."
    read -r -p "Enter EarnApp token: " token

    if [[ -z "$token" ]]; then
        log::die "Token cannot be empty."
    fi

    earnapp::_save_token "$token"
    EARNAPP_TOKEN="$token"
}

earnapp::_ensure_token() {
    earnapp::_load_token || earnapp::_prompt_token
}

###############################################
# SECTION: Container lifecycle
###############################################

earnapp::_pull_image() {
    log::info "Pulling latest EarnApp image…"
    docker pull "$EARNAPP_IMAGE" || log::die "Failed to pull EarnApp image."
    log::ok "Image updated."
}

earnapp::_remove_old_container() {
    if utils::container_exists "$EARNAPP_CONTAINER"; then
        log::warn "Removing old EarnApp container…"
        docker rm -f "$EARNAPP_CONTAINER" >/dev/null
    fi
}

earnapp::_run_container() {
    log::info "Starting EarnApp container…"

    docker run -d \
        --name "$EARNAPP_CONTAINER" \
        --restart unless-stopped \
        -e EARNAPP_DEVICE_TOKEN="$EARNAPP_TOKEN" \
        -v "$EARNAPP_DIR:/data" \
        "$EARNAPP_IMAGE" \
        || log::die "Failed to start EarnApp container."

    log::ok "EarnApp container started."
}

earnapp::_self_heal() {
    log::info "Checking EarnApp container health…"
    utils::container_ensure "$EARNAPP_CONTAINER"
}

###############################################
# SECTION: Public API
###############################################

earnapp::install() {
    log::section "Installing EarnApp"

    earnapp::_ensure_dirs
    earnapp::_ensure_token
    earnapp::_pull_image
    earnapp::_remove_old_container
    earnapp::_run_container
    earnapp::_self_heal

    log::ok "EarnApp installation complete."
}

earnapp::update() {
    log::section "Updating EarnApp"

    earnapp::_ensure_dirs
    earnapp::_ensure_token
    earnapp::_pull_image
    earnapp::_remove_old_container
    earnapp::_run_container

    log::ok "EarnApp updated."
}

earnapp::register() {
    if command -v system::register_container >/dev/null 2>&1; then
        system::register_container "earnapp" "EarnApp passive income container"
        log::ok "EarnApp registered with container registry."
    else
        log::warn "system::register_container not found — skipping registry."
    fi
}

earnapp::init() {
    log::title "Initializing EarnApp Module"

    earnapp::install
    earnapp::register

    log::ok "EarnApp module complete."
}
