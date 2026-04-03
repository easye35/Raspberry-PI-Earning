#!/usr/bin/env bash
set -Eeuo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULE_DIR/logging.sh"
source "$MODULE_DIR/utils.sh"

log::section "Dashboard Service Verification"

log::info "Checking dashboard container status..."
if sudo docker ps --format '{{.Names}}' | grep -q '^earnbox-dashboard$'; then
  log::ok "Dashboard container is running."
else
  log::warn "Dashboard container is not running — attempting to start."
  COMPOSE_DIR="$(cd "$MODULE_DIR/.." && pwd)"
  (cd "$COMPOSE_DIR" && sudo docker compose up -d earnbox-dashboard)
  sleep 2
  if sudo docker ps --format '{{.Names}}' | grep -q '^earnbox-dashboard$'; then
    log::ok "Dashboard container started successfully."
  else
    log::fail "Unable to start dashboard container."
  fi
fi

log::success_block "Dashboard is available on port 8080."
