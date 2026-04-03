#!/usr/bin/env bash
set -euo pipefail

# Resolve module directory
MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared libraries
source "$MODULES_DIR/00-logging.sh"
source "$MODULES_DIR/00-utils.sh"

log_info "Module 10: Stopping containers and cleaning environment"

# Stop all containers safely
log_info "Stopping all running containers..."
if docker ps -q | grep -q .; then
    docker stop $(docker ps -q) || log_warn "Some containers failed to stop"
else
    log_info "No running containers found"
fi

# Remove stopped containers
log_info "Removing stopped containers..."
if docker ps -aq | grep -q .; then
    docker rm $(docker ps -aq) || log_warn "Some containers failed to remove"
else
    log_info "No containers to remove"
fi

# Remove unused images
log_info "Removing unused Docker images..."
docker image prune -af || log_warn "Image prune encountered issues"

# Remove unused volumes
log_info "Removing unused Docker volumes..."
docker volume prune -f || log_warn "Volume prune encountered issues"

# Remove unused networks
log_info "Removing unused Docker networks..."
docker network prune -f || log_warn "Network prune encountered issues"

log_success "Module 10 completed successfully"
