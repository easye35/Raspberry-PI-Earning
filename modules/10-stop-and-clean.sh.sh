#!/usr/bin/env bash
set -euo pipefail

# Logging library (provided by install.sh via LOG_LIB)
source "$LOG_LIB"

log::section "Stopping Docker & Cleaning Previous State"

# Stop Docker safely
log::step "Stopping Docker service (if running)"
if systemctl is-active --quiet docker; then
    sudo systemctl stop docker
    log::ok "Docker stopped"
else
    log::info "Docker was not running"
fi

# Kill any leftover dockerd processes
log::step "Killing any leftover dockerd processes"
sudo pkill -f dockerd 2>/dev/null || true
log::ok "No active dockerd processes remain"

# Remove stale mounts
log::step "Cleaning stale mounts under /mnt/appliance-data"
if mountpoint -q /mnt/appliance-data; then
    sudo umount -l /mnt/appliance-data || true
    log::ok "Unmounted /mnt/appliance-data"
else
    log::info "/mnt/appliance-data was not mounted"
fi

# Ensure directory exists
sudo mkdir -p /mnt/appliance-data

# Remove old Docker data on SD card (if present)
if [ -d /var/lib/docker ]; then
    log::step "Removing old Docker data from SD card (/var/lib/docker)"
    sudo rm -rf /var/lib/docker
    log::ok "Old Docker data removed"
else
    log::info "No existing Docker data found on SD card"
fi

log::ok "Environment cleaned and ready for HDD preparation"