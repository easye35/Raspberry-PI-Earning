#!/usr/bin/env bash
# EarnApp module (native binary, official installer)
# Requires: lib/logging.sh, lib/system.sh

EARNAPP_BIN="/usr/bin/earnapp"
EARNAPP_SERVICE="earnapp"
EARNAPP_DIR="/var/lib/earnapp"

##############################################
# Internal helpers
##############################################

earnapp::_install_native() {
  log::info "Installing EarnApp using official BrightData installer…"

  wget -qO- https://brightdata.com/static/earnapp/install.sh | sudo bash || \
    log::die "EarnApp installation failed."

  log::ok "EarnApp installed successfully."
}

earnapp::_ensure_service() {
  log::info "Ensuring EarnApp systemd service is enabled…"

  systemctl enable "${EARNAPP_SERVICE}" >/dev/null 2>&1 || true
  systemctl restart "${EARNAPP_SERVICE}" || \
    log::die "Failed to start EarnApp service."

  log::ok "EarnApp service is running."
}

earnapp::_verify() {
  if [[ ! -f "${EARNAPP_BIN}" ]]; then
    log::fail "EarnApp binary missing."
    return 1
  fi

  log::info "EarnApp version: $(${EARNAPP_BIN} --version 2>/dev/null || echo 'unknown')"
}

##############################################
# Public API
##############################################

earnapp::install() {
  log::section "EarnApp (Native Binary) – Install"

  earnapp::_install_native
  earnapp::_ensure_service
  earnapp::_verify
}

earnapp::update() {
  log::section "EarnApp – Update"

  earnapp::_install_native
  earnapp::_ensure_service
  earnapp::_verify
}

earnapp::register() {
  system::register_container "earnapp" "EarnApp native earning service"
}

earnapp::init() {
  earnapp::install
  earnapp::register
}
