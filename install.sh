#!/usr/bin/env bash
# Appliance-grade installer orchestrator for this repo

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${ROOT_DIR}/lib"
MODULE_DIR="${ROOT_DIR}/modules"

# Export library paths for all modules
export LOG_LIB="${LIB_DIR}/logging.sh"
export SYS_LIB="${LIB_DIR}/system.sh"
export DOCKER_LIB="${LIB_DIR}/docker.sh"

# ---------------------------------------------------------
# Load core libraries FIRST (logging must exist before use)
# ---------------------------------------------------------

source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/system.sh"
source "${LIB_DIR}/docker.sh"

# Load module libraries
source "${MODULE_DIR}/utils.sh"
source "${MODULE_DIR}/earnapp.sh"
source "${MODULE_DIR}/diagnostics.sh"

log::title "Raspberry Pi Earning Appliance Installer"

log::info "Root:      $ROOT_DIR"
log::info "Lib dir:   $LIB_DIR"
log::info "Modules:   $MODULE_DIR"

# ---------------------------------------------------------
# External Storage Preparation (HDD/SSD)
# ---------------------------------------------------------

log::section "Preparing external storage"

bash "${MODULE_DIR}/10-stop-and-clean.sh"
bash "${MODULE_DIR}/20-power-check.sh"
bash "${MODULE_DIR}/30-detect-storage.sh"
bash "${MODULE_DIR}/35-mount-and-prepare-storage.sh"
bash "${MODULE_DIR}/45-migrate-docker.sh"
bash "${MODULE_DIR}/50-verify-storage.sh"

# ---------------------------------------------------------
# Core System Setup
# ---------------------------------------------------------

log::section "Initializing core modules"
utils::init
system::preflight
system::update
system::install_dependencies
system::optimize

# ---------------------------------------------------------
# Docker + EarnApp Installation
# ---------------------------------------------------------

log::section "Installing Docker"
docker::init

log::section "Installing EarnApp"
earnapp::install

# ---------------------------------------------------------
# Final Diagnostics
# ---------------------------------------------------------

log::section "Final diagnostics"
diagnostics::run

log::title "Installation complete"
log::ok "Docker + EarnApp are configured and running."
log::info "You can re-run diagnostics with:"
echo "  sudo bash ${ROOT_DIR}/diagnostics.sh"
