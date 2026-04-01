#!/usr/bin/env bash
# EarnApp module (Docker, token-less onboarding)
# Requires: lib/logging.sh, lib/system.sh, lib/docker.sh

EARNAPP_CONTAINER="earnapp"
EARNAPP_IMAGE="fearnapp/earnapp:latest"
EARNAPP_DIR="/var/lib/earnapp"

##############################################
# Internal helpers
##############################################

earnapp::_ensure_dirs() {
  log::info "Ensuring EarnApp data directory exists at: ${EARNAPP_DIR}"
  mkdir -p "${EARNAPP_DIR}"
  chmod 700 "${EARNAPP_DIR}" || true
}

earnapp::_pull_image() {
  log::info "Pulling latest EarnApp Docker image: ${EARNAPP_IMAGE}"
docker::init
docker pull "${EARNAPP_IMAGE}"
}

earnapp::_remove_old_container() {
  if docker ps -a --format '{{.Names}}' | grep -q "^${EARNAPP_CONTAINER}$"; then
    log::warn "Existing EarnApp container found. Removing it for a clean install..."
    docker stop "${EARNAPP_CONTAINER}" || true
    docker rm "${EARNAPP_CONTAINER}" || true
  fi
}

earnapp::_run_container() {
  log::info "Starting EarnApp container: ${EARNAPP_CONTAINER}"

  docker run -d \
    --name "${EARNAPP_CONTAINER}" \
    --restart unless-stopped \
    -v "${EARNAPP_DIR}:/var/lib/earnapp" \
    "${EARNAPP_IMAGE}"

  log::ok "EarnApp container started."
  log::info "Visit your EarnApp dashboard to link this device if required."
}

earnapp::_self_heal() {
  # Optional: you can extend this later with a watchdog/systemd unit
  log::info "EarnApp self-heal hook (placeholder) – container is managed via Docker restart policy."
}

##############################################
# Public API
##############################################

earnapp::install() {
  log::section "EarnApp (Docker) – token-less install"

  earnapp::_ensure_dirs
  earnapp::_pull_image
  earnapp::_remove_old_container
  earnapp::_run_container
  earnapp::_self_heal
}

earnapp::update() {
  log::section "EarnApp (Docker) – update"

  earnapp::_ensure_dirs
  earnapp::_pull_image
  earnapp::_remove_old_container
  earnapp::_run_container
  earnapp::_self_heal
}

earnapp::register() {
  # Register with your appliance registry / dashboard
  system::register_container "${EARNAPP_CONTAINER}" "EarnApp passive income container"
}

earnapp::init() {
  earnapp::install
  earnapp::register
}
