#!/usr/bin/env bash
# Module 45: Move Docker to external storage (dynamic, safe)

set -Eeuo pipefail

# Load logging
if [[ -n "${LOG_LIB:-}" && -f "$LOG_LIB" ]]; then
    # shellcheck source=/dev/null
    source "$LOG_LIB"
else
    log::info(){ echo "[INFO] $*"; }
    log::warn(){ echo "[WARN] $*"; }
    log::error(){ echo "[ERROR] $*"; }
    log::success(){ echo "[SUCCESS] $*"; }
    log::section(){ echo; echo "=== $* ==="; echo; }
fi

log::section "Migrating Docker to External Storage"

STORAGE_ENV="/tmp/storage.env"

if [[ ! -f "$STORAGE_ENV" ]]; then
    log::error "Missing $STORAGE_ENV — storage pipeline not initialized."
    exit 1
fi

# Load DEVICE, PARTITION, MOUNT_POINT
source "$STORAGE_ENV"

if [[ -z "${MOUNT_POINT:-}" ]]; then
    log::error "MOUNT_POINT not found in $STORAGE_ENV"
    exit 1
fi

log::info "Using storage mountpoint: $MOUNT_POINT"

###############################################################################
# Determine Docker data directory
###############################################################################

DOCKER_DIR="$MOUNT_POINT/docker"

log::info "Target Docker directory: $DOCKER_DIR"

mkdir -p "$DOCKER_DIR"

###############################################################################
# Stop Docker safely
###############################################################################

log::info "Stopping Docker service (if running)"
systemctl stop docker 2>/dev/null || true
sleep 1

###############################################################################
# If Docker already migrated, skip rsync
###############################################################################

if [[ -L /var/lib/docker ]]; then
    CURRENT_TARGET="$(readlink -f /var/lib/docker)"
    if [[ "$CURRENT_TARGET" == "$DOCKER_DIR" ]]; then
        log::info "Docker already migrated — skipping data copy."
        systemctl start docker
        log::success "Docker migration already complete."
        exit 0
    fi
fi

###############################################################################
# Move Docker data
###############################################################################

if [[ -d /var/lib/docker ]]; then
    log::info "Copying Docker data to $DOCKER_DIR"
    rsync -aHAX --delete /var/lib/docker/ "$DOCKER_DIR/"
else
    log::warn "/var/lib/docker does not exist — creating fresh directory."
    mkdir -p "$DOCKER_DIR"
fi

###############################################################################
# Replace /var/lib/docker with symlink
###############################################################################

log::info "Replacing /var/lib/docker with symlink → $DOCKER_DIR"

rm -rf /var/lib/docker
ln -s "$DOCKER_DIR" /var/lib/docker

###############################################################################
# Restart Docker
###############################################################################

log::info "Starting Docker service"
systemctl start docker 2>/dev/null || true
sleep 1

if systemctl is-active --quiet docker; then
    log::success "Docker successfully migrated to: $DOCKER_DIR"
else
    log::error "Docker failed to start after migration."
    exit 1
fi
