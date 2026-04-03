#!/usr/bin/env bash
set -Eeuo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULE_DIR/logging.sh"
source "$MODULE_DIR/utils.sh"

log::section "Diagnostics Snapshot"

DATA_ROOT="/mnt/storage"
if ! mountpoint -q /mnt/storage 2>/dev/null; then
  DATA_ROOT="/opt/earnbox"
fi

LOG_DIR="$DATA_ROOT/logs"
sudo mkdir -p "$LOG_DIR"

STAMP="$(date +'%Y%m%d-%H%M%S')"
OUT="$LOG_DIR/diagnostics-$STAMP.log"

log::step "Writing diagnostics to $OUT"

{
  echo "=== Diagnostics Snapshot: $STAMP ==="
  echo
  echo "== System =="
  uname -a || true
  echo
  echo "== Uptime =="
  uptime || true
  echo
  echo "== Disk Usage =="
  df -h || true
  echo
  echo "== Docker Info =="
  docker info || true
  echo
  echo "== Docker Containers =="
  docker ps -a || true
  echo
  echo "== dmesg (tail) =="
  dmesg | tail -n 50 || true
} | sudo tee "$OUT" >/dev/null

log::success_block "Diagnostics snapshot captured at $OUT"
