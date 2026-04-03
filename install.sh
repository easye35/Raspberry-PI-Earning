#!/usr/bin/env bash
# Raspberry Pi Earning Appliance — Full Installer Orchestrator

###############################################################################
# Strict mode + error trap
###############################################################################
set -Eeuo pipefail
trap 'echo "❌ ERROR on line $LINENO: $BASH_COMMAND" >&2' ERR

###############################################################################
# Self‑elevation guard
###############################################################################
if [[ $EUID -ne 0 ]]; then
    echo "Installer is not running as root — elevating..."
    exec sudo -E bash "$0" "$@"
fi

echo "INSTALLER RUNNING AS ROOT (EUID=$EUID)"
echo "--------------------------------------"

###############################################################################
# Resolve directories
###############################################################################
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${ROOT_DIR}/lib"
MODULE_DIR="${ROOT_DIR}/modules"

export LOG_LIB="${LIB_DIR}/logging.sh"
export SYS_LIB="${LIB_DIR}/system.sh"
export DOCKER_LIB="${LIB_DIR}/docker.sh"

###############################################################################
# Load logging library
###############################################################################
if [[ -f "$LOG_LIB" ]]; then
    source "$LOG_LIB"
else
    echo "⚠ logging.sh missing — using fallback echo logger"
    log::info()    { echo "[INFO] $*"; }
    log::warn()    { echo "[WARN] $*"; }
    log::error()   { echo "[ERROR] $*"; }
    log::success() { echo "[SUCCESS] $*"; }
    log::title()   { echo "=== $* ==="; }
    log::section() { echo "--- $* ---"; }
fi

log::title "Raspberry Pi Earning Appliance Installer"
log::info  "Root directory:   $ROOT_DIR"
log::info  "Library directory: $LIB_DIR"
log::info  "Module directory:  $MODULE_DIR"

###############################################################################
# Optional logging normalization
###############################################################################
if [[ -x "${ROOT_DIR}/fix-logging.sh" ]]; then
    log::info "Normalizing logging syntax..."
    bash "${ROOT_DIR}/fix-logging.sh"
else
    log::warn "fix-logging.sh not found — skipping logging normalization."
fi

###############################################################################
# Module runner
###############################################################################
run_module() {
    local module="$1"
    local path="${MODULE_DIR}/${module}"

    if [[ ! -f "$path" ]]; then
        log::error "Module missing: $module"
        exit 1
    fi

    log::section "Running module: $module"
    chmod +x "$path"
    bash "$path"
    log::success "Module completed: $module"
}

###############################################################################
# Execute modules in order
###############################################################################
MODULES=(
    "10-stop-and-clean.sh"
    "20-power-check.sh"
    "30-detect-storage.sh"
    "35-mount-and-prepare-storage.sh"
    "40-migrate-docker.sh"
    "50-verify-storage.sh"
)

for module in "${MODULES[@]}"; do
    run_module "$module"
done

###############################################################################
# Completion
###############################################################################
log::success "All modules completed successfully!"
log::title   "Raspberry Pi Earning Appliance is ready."
