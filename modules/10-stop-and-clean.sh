#!/usr/bin/env bash
set -euo pipefail

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logging.sh"
source "$SCRIPT_DIR/../lib/utils.sh"

###############################################################################
# Module 10: Stop containers and clean Docker environment
###############################################################################

# Resolve directories
MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MODULES_DIR/.." && pwd)"

# Load shared libraries
source "$ROOT_DIR/lib/logging.sh"
source "$ROOT_DIR/lib/utils.sh"

log_section "Module 10: Stopping containers and cleaning environment"

###############################################################################
# Safety checks
###############################################################################

if ! command -v docker >/dev/null 2>&1; then
    log_warn "Docker is not installed or not in PATH. Skipping Docker cleanup."
    log_success "Module 10 completed (no Docker present)"
    exit 0
fi

if ! docker info >/dev/null 2>&1; then
    log_warn "Docker daemon is not responding. Skipping Docker cleanup."
    log_success "Module 10 completed (Docker not running)"
    exit 0
fi

###############################################################################
# Helpers
###############################################################################

clean_containers() {
    log_info "Checking for running containers..."
    if docker ps -q | grep -q .; then
        log_info "Stopping running containers..."
        if ! docker stop "$(docker ps -q)"; then
            log_warn "Some containers may have failed to stop."
        fi
    else
        log_info "No running containers found."
    fi

    log_info "Checking for stopped containers to remove..."
    if docker ps -aq | grep -q .; then
        log_info "Removing stopped containers..."
        if ! docker rm "$(docker ps -aq)"; then
            log_warn "Some containers may have failed to remove."
        fi
    else
        log_info "No containers to remove."
    fi
}

clean_images() {
    log_info "Pruning unused Docker images..."
    if ! docker image prune -af >/dev/null 2>&1; then
        log_warn "Image prune encountered issues."
    else
        log_info "Unused images pruned."
    fi
}

clean_volumes() {
    log_info "Pruning unused Docker volumes..."
    if ! docker volume prune -f >/dev/null 2>&1; then
        log_warn "Volume prune encountered issues."
    else
        log_info "Unused volumes pruned."
    fi
}

clean_networks() {
    log_info "Pruning unused Docker networks..."
    if ! docker network prune -f >/dev/null 2>&1; then
        log_warn "Network prune encountered issues."
    else
        log_info "Unused networks pruned."
    fi
}

###############################################################################
# Execution
###############################################################################

log_info "Starting Docker cleanup sequence..."

clean_containers
clean_images
clean_volumes
clean_networks

log_success "Module 10: Docker environment cleanup completed successfully."
exit 0
