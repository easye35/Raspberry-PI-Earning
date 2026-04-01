#!/usr/bin/env bash

# EarnApp Module (Modern Registration Flow)
# -----------------------------------------
# This module:
#   - Starts the EarnApp container
#   - Extracts the registration URL from logs
#   - Displays the link to the user
#   - Waits for confirmation
#   - Registers the container in the appliance registry

earnapp::start_container() {
    log::info "Starting EarnApp container…"
    docker compose up -d earnapp >/dev/null 2>&1

    if [[ $? -ne 0 ]]; then
        log::error "Failed to start EarnApp container."
        return 1
    fi

    log::ok "EarnApp container started."
}

earnapp::get_registration_url() {
    log::info "Waiting for EarnApp to generate registration link…"

    local url=""
    local attempts=0
    local max_attempts=20

    # Poll logs until the registration URL appears
    while [[ -z "$url" && $attempts -lt $max_attempts ]]; do
        sleep 2
        attempts=$((attempts + 1))

        url=$(docker logs earnapp 2>&1 | grep -o "https://earnapp.com/r/device/[^ ]*")

        if [[ -n "$url" ]]; then
            echo "$url"
            return 0
        fi
    done

    return 1
}

earnapp::register() {
    log::info "Initializing EarnApp module…"

    earnapp::start_container || return 1

    local url
    url=$(earnapp::get_registration_url)

    if [[ -z "$url" ]]; then
        log::error "Could not retrieve EarnApp registration URL."
        log::error "Try running: docker logs earnapp"
        return 1
    fi

    echo
    log::ok "EarnApp device is ready for registration!"
    echo -e "\n\e[34m➜\e[0m Open this link in your browser to register your device:"
    echo -e "\e[32m$url\e[0m\n"

    read -p "Press Enter after you have registered this device…" _

    log::ok "EarnApp device registered."
}

earnapp::install() {
    log::info "Installing EarnApp module…"

    system::register_container "earnapp" "EarnApp Passive Income Node"

    earnapp::register || return 1

    log::ok "EarnApp module installation complete."
}
