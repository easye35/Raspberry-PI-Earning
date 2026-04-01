#!/usr/bin/env bash
# Appliance-grade installer orchestrator for this repo

set -e

ROOT_DIR="$(dirname "$0")"
LIB_DIR="${ROOT_DIR}/lib"
MODULE_DIR="${ROOT_DIR}/modules"

# Core libs
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/system.sh"

# Modules
source "${MODULE_DIR}/utils.sh"
source "${MODULE_DIR}/docker.sh"
source "${MODULE_DIR}/earnapp.sh"
source "${MODULE_DIR}/diagnostics.sh"

log::title "Raspberry Pi Earning Appliance Installer"

log::info "Root:      $ROOT_DIR"
log::info "Lib dir:   $LIB_DIR"
log::info "Modules:   $MODULE_DIR"

log::section "Initializing core modules"
utils::init
system::init

log::section "Installing Docker"
docker::init

log::section "Installing EarnApp"
earnapp::init

log::section "Final diagnostics"
diagnostics::run

log::title "Installation complete"
log::ok "Docker + EarnApp are configured and running."
log::info "You can re-run diagnostics with:"
echo "  sudo bash ${ROOT_DIR}/diagnostics.sh"
