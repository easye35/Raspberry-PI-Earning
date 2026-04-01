#!/usr/bin/env bash
# Appliance-grade installer orchestrator
# Loads modules, runs them in order, handles reruns safely.

set -e

ROOT_DIR="$(dirname "$0")"
MODULE_DIR="${ROOT_DIR}/modules"
LIB_DIR="${ROOT_DIR}/lib"

# Load logging first (colors included)
# shellcheck source=lib/logging.sh
source "${LIB_DIR}/logging.sh"

###############################################
# SECTION: Module Loader
###############################################

load_module() {
    local module="$1"
    local file="${MODULE_DIR}/${module}.sh"

    if [[ ! -f "$file" ]]; then
        log::fail "Module not found: ${module}.sh"
        return 1
    fi

    # shellcheck source=/dev/null
    source "$file"
    log::ok "Loaded module: $module"
}

###############################################
# SECTION: Module Execution Wrapper
###############################################

run_module() {
    local module="$1"
    local entry="$2"

    log::section "Running module: $module"

    if ! command -v "${module}::${entry}" >/dev/null 2>&1; then
        log::fail "Entry function ${module}::${entry} not found."
        return 1
    fi

    # Run module with isolation
    if "${module}::${entry}"; then
        log::ok "${module} completed successfully."
    else
        log::fail "${module} failed."
        return 1
    fi
}

###############################################
# SECTION: Preflight
###############################################

log::title "Raspberry Pi Appliance Installer"

log::info "Installer root: $ROOT_DIR"
log::info "Loading modules…"

# Load core modules
load_module "utils"
load_module "system"
load_module "docker"
load_module "earnapp"
load_module "diagnostics"

###############################################
# SECTION: Install Flow
###############################################

log::section "Starting Appliance Installation"

# Order matters
run_module "utils" "init"
run_module "system" "init"
run_module "docker" "init"
run_module "earnapp" "init"

###############################################
# SECTION: Final Diagnostics
###############################################

log::section "Running Final Diagnostics"
diagnostics::run

###############################################
# SECTION: Summary
###############################################

log::title "Installation Complete"

log::ok "Your Raspberry Pi earning appliance is fully installed."
log::ok "Docker is running, EarnApp is active, and diagnostics are clean."

echo ""
log::info "To view diagnostics again, run:"
echo "    sudo bash ${ROOT_DIR}/modules/diagnostics.sh"
echo ""

log::ok "System ready."
