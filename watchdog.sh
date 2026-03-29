#!/bin/sh

INTERVAL=60
SERVICES="honeygain pawns watchtower dozzle glances dashboard diagnostics"

echo "[watchdog] Starting watchdog loop..."

while true; do
  if ! docker ps >/dev/null 2>&1; then
    echo "[watchdog] Docker daemon unhealthy."
  else
    for S in $SERVICES; do
      if ! docker ps --format '{{.Names}}' | grep -q "^${S}$"; then
        echo "[watchdog] Restarting ${S}..."
        docker start "${S}" 2>/dev/null || docker restart "${S}" 2>/dev/null || true
      fi
    done
  fi
  sleep "${INTERVAL}"
done
