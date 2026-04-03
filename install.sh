#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# Earnbox Installer — Full Appliance Setup
# HDD-aware, modular, safe, and idempotent
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR/modules"

###############################################################################
# Logging helpers
###############################################################################

log_section() {
  echo
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
}

log_step()   { echo "[STEP] $1"; }
log_info()   { echo "[INFO] $1"; }
log_ok()     { echo "[OK]   $1"; }
log_warn()   { echo "[WARN] $1"; }
log_fail()   { echo "[FAIL] $1"; exit 1; }

###############################################################################
# Module runner
###############################################################################

run_module() {
  local module="$1"
  local path="$MODULE_DIR/$module"

  if [[ ! -f "$path" ]]; then
    log_warn "Module not found: $module — skipping."
    return
  fi

  echo
  echo "▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒"
  echo "  Running module: $module"
  echo "▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒"
  echo

  bash "$path"
}

###############################################################################
# Detect HDD vs no-HDD
###############################################################################

DATA_ROOT="/mnt/storage"
if ! mountpoint -q /mnt/storage 2>/dev/null; then
  log_warn "/mnt/storage is not mounted — falling back to /opt/earnbox"
  DATA_ROOT="/opt/earnbox"
fi

log_info "Using data root: $DATA_ROOT"

###############################################################################
# Installer Start
###############################################################################

START_TIME="$(date)"
log_section "Earnbox Installer Started — $START_TIME"

###############################################################################
# Core system prep
###############################################################################

run_module "10-stop-and-clean.sh"
run_module "20-power-check.sh"
run_module "30-detect-storage.sh"
run_module "35-mount-and-prepare-storage.sh"
run_module "40-migrate-storage.sh"
run_module "45-migrate-docker.sh"
run_module "50-verify-storage.sh"

###############################################################################
# New earning-appliance modules
###############################################################################

run_module "60-install-containers.sh"
run_module "70-dashboard.sh"
run_module "80-diagnostics.sh"
run_module "90-self-heal.sh"

###############################################################################
# Done
###############################################################################

END_TIME="$(date)"
echo
echo "=== Earnbox installation complete: $END_TIME ==="
echo
