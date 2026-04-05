#!/usr/bin/env bash
set -euo pipefail

MODULE_NAME="EarnApp"
LOG_FILE="/var/log/earnbox/installer.log"

log() {
    echo "[$MODULE_NAME] $1" | tee -a "$LOG_FILE"
}

install_earnapp() {
    log "Starting EarnApp installation..."

    # Ensure wget exists
    if ! command -v wget >/dev/null 2>&1; then
        log "wget not found, installing..."
        sudo apt-get update -y >> "$LOG_FILE" 2>&1
        sudo apt-get install -y wget >> "$LOG_FILE" 2>&1
    fi

    # Download installer
    TMP_SCRIPT="/tmp/earnapp.sh"
    log "Downloading EarnApp installer..."
    wget -qO- https://brightdata.com/static/earnapp/install.sh > "$TMP_SCRIPT"

    # Basic sanity check
    if ! grep -q "earnapp" "$TMP_SCRIPT"; then
        log "ERROR: Installer script failed sanity check. Aborting."
        exit 1
    fi

    # Run installer
    log "Running EarnApp installer..."
    sudo bash "$TMP_SCRIPT" >> "$LOG_FILE" 2>&1

    log "EarnApp installation complete."
}

health_check() {
    log "Running EarnApp health check..."

    if systemctl is-active --quiet earnapp; then
        log "EarnApp service is active."
    else
        log "EarnApp service is NOT active. Attempting restart..."
        sudo systemctl restart earnapp || true
    fi

    if systemctl is-active --quiet earnapp; then
        log "EarnApp is healthy."
    else
        log "EarnApp is still not running. Manual intervention required."
    fi
}

case "${1:-}" in
    install)
        install_earnapp
        health_check
        ;;
    health)
        health_check
        ;;
    *)
        echo "Usage: $0 {install|health}"
        exit 1
        ;;
esac
