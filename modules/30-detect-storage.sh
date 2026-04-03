#!/usr/bin/env bash
# Module 30: Detect external storage (POSIX-safe)

set -Eeuo pipefail

# Load logging
if [[ -n "${LOG_LIB:-}" && -f "$LOG_LIB" ]]; then source "$LOG_LIB"; else
    log::info(){ echo "[INFO] $*"; }
    log::warn(){ echo "[WARN] $*"; }
    log::error(){ echo "[ERROR] $*"; }
    log::success(){ echo "[SUCCESS] $*"; }
    log::section(){ echo; echo "=== $* ==="; echo; }
fi

log::section "Detecting External Storage"

STORAGE_ENV="/tmp/storage.env"
rm -f "$STORAGE_ENV"; touch "$STORAGE_ENV"; chmod 600 "$STORAGE_ENV"

log::info "[Step] Scanning for USB storage devices"

CANDIDATES="$(lsblk -ndo NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}' | grep -E '^/dev/sd' || true)"

if [[ -z "$CANDIDATES" ]]; then
    log::error "No /dev/sdX disks detected."
    exit 1
fi

DEVICE="$(echo "$CANDIDATES" | head -n 1)"
log::info "Detected disk: $DEVICE"

echo "DEVICE=$DEVICE" >> "$STORAGE_ENV"

log::success "Storage detection complete."
