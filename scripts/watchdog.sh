#!/usr/bin/env bash
set -e

LOG_TAG="[watchdog]"

echo "$LOG_TAG Running health checks at $(date)"

container_defined() {
  local name="$1"
  docker compose config --services 2>/dev/null | grep -q "^${name}$"
}

check_container() {
  local name="$1"
  if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
    echo "$LOG_TAG Container ${name} is not running. Attempting restart..."
    if docker ps -a --format '{{.Names}}' | grep -q "^${name}$"; then
      docker start "${name}" || true
    elif container_defined "${name}"; then
      docker compose up -d "${name}" || true
    else
      echo "$LOG_TAG Container ${name} is not defined in compose. Skipping."
    fi
  else
    echo "$LOG_TAG Container ${name} is healthy."
  fi
}

check_container "honeygain"
check_container "pawns"
check_container "dozzle"
check_container "traffmonetizer"
check_container "earnings"
check_container "backend"
check_container "earnbox"

if command -v systemctl >/dev/null 2>&1; then
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
else
  echo "$LOG_TAG systemctl unavailable on this OS. Skipping native EarnApp checks."
fi

echo "$LOG_TAG Watchdog run complete."
