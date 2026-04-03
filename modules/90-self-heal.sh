#!/usr/bin/env bash
set -Eeuo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULE_DIR/logging.sh"
source "$MODULE_DIR/utils.sh"

log::section "Self-Heal Check"

DATA_ROOT="/mnt/storage"
if ! mountpoint -q /mnt/storage 2>/dev/null; then
  DATA_ROOT="/opt/earnbox"
fi

COMPOSE_DIR="$(cd "$MODULE_DIR/.." && pwd)"

###############################################################################
# Ensure Docker is running
###############################################################################

if ! systemctl is-active --quiet docker; then
  log::warn "Docker service is not active — attempting restart."
  sudo systemctl restart docker || log::fail "Failed to restart Docker."
  log::ok "Docker restarted."
fi

###############################################################################
# Ensure compose stack is up
###############################################################################

if [[ -f "$COMPOSE_DIR/docker-compose.yml" ]]; then
  log::info "Ensuring compose stack is up."
  (cd "$COMPOSE_DIR" && sudo DATA_ROOT="$DATA_ROOT" docker compose up -d)
else
  log::warn "No docker-compose.yml found — skipping stack self-heal."
fi

log::success_block "Self-heal pass completed."
