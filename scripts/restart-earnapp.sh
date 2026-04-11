#!/usr/bin/env bash
set -e

if systemctl list-unit-files | grep -q "^earnapp.service"; then
  echo "[restart-earnapp] Restarting native EarnApp..."
  sudo systemctl restart earnapp.service || {
    echo "[restart-earnapp] Failed to restart EarnApp."
    exit 1
  }
  echo "[restart-earnapp] Done."
else
  echo "[restart-earnapp] earnapp.service not found."
  exit 1
fi
