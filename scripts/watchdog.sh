#!/usr/bin/env bash
set -e

LOG_TAG="[watchdog]"

echo "$LOG_TAG Running health checks at $(date)"

check_container() {
  local name="$1"
  if ! docker ps --format '{{.Names}}' | grep -q "^${name}\$"; then
    echo "$LOG_TAG Container ${name} is not running. Attempting restart..."
    docker start "${name}" || docker compose up -d "${name}" || true
  else
    echo "$LOG_TAG Container ${name} is healthy."
  fi
}

check_container "honeygain"
check_container "pawns"
check_container "watchtower"
check_container "glances"
check_container "dozzle"

echo "$LOG_TAG Checking native EarnApp service..."
if systemctl list-unit-files | grep -q "^earnapp.service"; then
  if ! systemctl is-active --quiet earnapp.service; then
    echo "$LOG_TAG EarnApp is not active. Restarting..."
    sudo systemctl restart earnapp.service || true
  else
    echo "$LOG_TAG EarnApp service is active."
  fi
else
  echo "$LOG_TAG EarnApp service not found. Skipping."
fi

echo "$LOG_TAG Watchdog run complete."
