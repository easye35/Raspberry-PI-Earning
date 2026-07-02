#!/usr/bin/env bash
set -euo pipefail

# Self-heal script for earnings service
# - Ensures earnings container is present and running
# - Verifies SQLite DB integrity, backs up corrupted DB, and restores from latest JSON snapshot
# - Copies fallback snapshot from repo if host snapshot is missing

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="$ROOT/data"
FALLBACK_JSON="$ROOT/earnings/data/latest_earnings.json"
DC_COMMAND="docker compose"

# Load optional overrides (ALLOW_DESTROY=csv list, REPO_DIR etc.)
if [ -f /etc/default/selfheal ]; then
  # shellcheck disable=SC1090
  . /etc/default/selfheal
fi

# Default: allow destructive recovery for ALL compose services so self-heal
# can fully recover after a power failure without user interaction.
# Can still be overridden by setting `ALLOW_DESTROY` in /etc/default/selfheal.
svc_list=$($DC_COMMAND config --services 2>/dev/null || true)
if [ -z "${ALLOW_DESTROY:-}" ]; then
  if [ -n "$svc_list" ]; then
    ALLOW_DESTROY=$(echo "$svc_list" | tr '\n' ',' | sed 's/,$//')
  else
    ALLOW_DESTROY="netdata,selfheal,dozzle"
  fi
fi

# If user explicitly sets ALLOW_DESTROY_ALL=1, rebuild ALLOW_DESTROY from compose services
if [ "${ALLOW_DESTROY_ALL:-0}" = "1" ]; then
  if [ -n "$svc_list" ]; then
    ALLOW_DESTROY=$(echo "$svc_list" | tr '\n' ',' | sed 's/,$//')
  fi
fi

log() { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"; }

if ! command -v docker >/dev/null 2>&1; then
  log "docker CLI not found. Install Docker and re-run."
  exit 1
fi

cd "$ROOT"

# Recreate .env from example if missing so services have required env vars
if [ ! -f "$ROOT/.env" ] && [ -f "$ROOT/.env.example" ]; then
  log ".env missing — recreating from .env.example (please update secrets)"
  cp "$ROOT/.env.example" "$ROOT/.env" || log "failed to copy .env.example to .env"
  chmod 600 "$ROOT/.env" || true
fi

# Protected files to backup before destructive actions (can be overridden in /etc/default/selfheal)
PROTECT_FILES=".env,.env.local"
if [ -n "${PROTECT_FILES_OVERRIDE:-}" ]; then
  PROTECT_FILES="$PROTECT_FILES_OVERRIDE"
fi

protect_and_backup() {
  BKDIR="$ROOT/backups/protect/$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p "$BKDIR"
  IFS=',' read -r -a pfiles <<<"$PROTECT_FILES"
  for pf in "${pfiles[@]}"; do
    pf_trim=$(echo "$pf" | xargs)
    if [ -f "$ROOT/$pf_trim" ]; then
      cp "$ROOT/$pf_trim" "$BKDIR/" || log "failed to backup $pf_trim"
      log "Backed up protected file $pf_trim to $BKDIR/"
    fi
  done
}

# Backup protected files before potential destructive operations
protect_and_backup

# Ensure earnings container exists and is running
if docker ps -a --format '{{.Names}}' | grep -q '^earnings$'; then
  RUNNING=$(docker inspect -f '{{.State.Running}}' earnings 2>/dev/null || echo "false")
  if [ "$RUNNING" != "true" ]; then
    log "Earnings container not running — attempting to rebuild and start"
    $DC_COMMAND up -d --build earnings || log "docker compose up failed"
  else
    log "Earnings container is running"
  fi
else
  log "Earnings container missing — creating via docker compose"
  $DC_COMMAND up -d --build earnings
fi

mkdir -p "$DATA_DIR"

# Ensure a latest JSON snapshot exists in host data dir
if [ ! -f "$DATA_DIR/latest_earnings.json" ]; then
  if [ -f "$FALLBACK_JSON" ]; then
    cp "$FALLBACK_JSON" "$DATA_DIR/latest_earnings.json"
    log "Copied repo fallback latest_earnings.json to $DATA_DIR/latest_earnings.json"
  else
    log "No fallback snapshot found in repo (earnings/data/latest_earnings.json)"
  fi
else
  log "Host snapshot exists: $DATA_DIR/latest_earnings.json"
fi

DB="$DATA_DIR/earnings.db"

restore_from_json() {
  JSON_PATH="$1"
  log "Restoring DB from JSON: $JSON_PATH"
  python3 - <<PY
import json,sqlite3,os
p = r"$JSON_PATH"
with open(p) as f:
    s=json.load(f)
db=r"$DB"
os.makedirs(os.path.dirname(db), exist_ok=True)
conn=sqlite3.connect(db)
cur=conn.cursor()
cur.execute('''CREATE TABLE IF NOT EXISTS earnings (
id INTEGER PRIMARY KEY AUTOINCREMENT,
timestamp TEXT NOT NULL,
honeygain REAL NOT NULL,
pawns REAL NOT NULL,
total REAL NOT NULL DEFAULT 0.0,
daily_change REAL,
projected_30_day REAL,
daily_average_30_day REAL
)''')
cur.execute("INSERT INTO earnings (timestamp,honeygain,pawns,total,daily_change,projected_30_day) VALUES (?,?,?,?,?,?)",
            (s.get('timestamp'), s.get('honeygain',0), s.get('pawns',0), s.get('honeygain',0)+s.get('pawns',0), s.get('daily_change',0), s.get('projected_30_day',0)))
conn.commit()
conn.close()
print('OK')
PY
}

if [ -f "$DB" ]; then
  if command -v sqlite3 >/dev/null 2>&1; then
    RESULT=$(sqlite3 "$DB" "PRAGMA integrity_check;" 2>/dev/null || echo "ERROR")
    if [ "$RESULT" = "ok" ]; then
      log "SQLite integrity check: OK"
    else
      log "SQLite integrity check failed: $RESULT"
      TS=$(date -u +%Y%m%dT%H%M%SZ)
      mv "$DB" "${DB}.bak.${TS}"
      log "Backed up corrupted DB to ${DB}.bak.${TS}"
      JSON="$DATA_DIR/latest_earnings.json"
      if [ ! -f "$JSON" ] && [ -f "$FALLBACK_JSON" ]; then JSON="$FALLBACK_JSON"; fi
      if [ -f "$JSON" ]; then
        restore_from_json "$JSON"
        log "DB restored from snapshot"
      else
        log "No snapshot found to restore DB"
      fi
    fi
  else
    log "sqlite3 CLI not available; cannot perform integrity check. Skipping."
  fi
else
  log "No DB present — attempting to create from snapshot"
  JSON="$DATA_DIR/latest_earnings.json"
  if [ ! -f "$JSON" ] && [ -f "$FALLBACK_JSON" ]; then JSON="$FALLBACK_JSON"; fi
  if [ -f "$JSON" ]; then
    restore_from_json "$JSON"
    log "DB created from snapshot"
  else
    log "No snapshot available to create DB"
  fi
fi

# Restart earnings container to pick up DB and snapshot changes
log "Restarting earnings container"
if ! docker restart earnings >/dev/null 2>&1; then
  log "docker restart failed — attempting docker compose up"
  $DC_COMMAND up -d --build earnings
fi

#########################
#+ Generic service self-heal for all compose services
#########################

in_allowlist() {
  # returns 0 if first arg is in comma-separated ALLOW_DESTROY
  svc="$1"
  [ -z "${ALLOW_DESTROY:-}" ] && return 1
  IFS=',' read -r -a arr <<<"${ALLOW_DESTROY}"
  for v in "${arr[@]}"; do
    if [ "${v}" = "$svc" ]; then
      return 0
    fi
  done
  return 1
}

heal_service() {
  svc="$1"
  log "Starting heal for service: $svc"

  # ignore the selfheal service itself
  if [ "$svc" = "selfheal" ]; then
    log "Skipping selfheal service"
    return 0
  fi

  exists=$(docker ps -a --format '{{.Names}}' | grep -E "^${svc}$" || true)
  if [ -n "$exists" ]; then
    state=$(docker inspect -f '{{.State.Status}}' "$svc" 2>/dev/null || echo "unknown")
    if [ "$state" = "running" ]; then
      log "$svc is running; skipping"
      return 0
    else
      log "$svc exists but state=$state — attempting restart"
      docker restart "$svc" >/dev/null 2>&1 || log "docker restart $svc failed"
      sleep 2
      state=$(docker inspect -f '{{.State.Status}}' "$svc" 2>/dev/null || echo "unknown")
      if [ "$state" = "running" ]; then
        log "$svc restarted successfully"
        return 0
      fi
    fi
  else
    log "$svc container missing — will create via docker compose"
  fi

  # Try recreate via compose
  log "Attempting docker compose recreate for $svc"
  $DC_COMMAND up -d --no-deps --force-recreate "$svc" || log "compose up failed for $svc"
  sleep 3
  state=$(docker inspect -f '{{.State.Status}}' "$svc" 2>/dev/null || echo "missing")
  if [ "$state" = "running" ]; then
    log "$svc is running after compose recreate"
    return 0
  fi

  # Remove container and recreate
  log "Removing $svc container and recreating"
  docker rm -f "$svc" >/dev/null 2>&1 || true
  $DC_COMMAND up -d --no-deps "$svc" || log "compose up after rm failed for $svc"
  sleep 3
  state=$(docker inspect -f '{{.State.Status}}' "$svc" 2>/dev/null || echo "missing")
  if [ "$state" = "running" ]; then
    log "$svc running after remove+create"
    return 0
  fi

  # Destructive steps only if allowed
  if in_allowlist "$svc"; then
    log "$svc allowed for destructive recovery — attempting volume removal"
    volumes=$(docker volume ls --format '{{.Name}}' | grep -i "$svc" || true)
    if [ -n "$volumes" ]; then
      for v in $volumes; do
        log "Removing volume $v"
        docker volume rm -f "$v" >/dev/null 2>&1 || log "failed removing volume $v"
      done
      log "Recreating $svc after volume removal"
      $DC_COMMAND up -d --no-deps "$svc" || log "compose up failed after removing volumes for $svc"
      sleep 3
      state=$(docker inspect -f '{{.State.Status}}' "$svc" 2>/dev/null || echo "missing")
      if [ "$state" = "running" ]; then
        log "$svc running after volume removal"
        return 0
      fi
    else
      log "No volumes found for $svc to remove"
    fi

    log "Attempting to remove images for $svc and rebuild"
    imgs=$(docker image ls --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep -i "$svc" || true)
    if [ -n "$imgs" ]; then
      echo "$imgs" | while read -r line; do
        id=$(echo "$line" | awk '{print $2}')
        log "Removing image $id"
        docker rmi -f "$id" >/dev/null 2>&1 || log "failed removing image $id"
      done
      log "Rebuilding $svc via compose"
      $DC_COMMAND up -d --build "$svc" || log "compose build up failed for $svc"
      sleep 4
      state=$(docker inspect -f '{{.State.Status}}' "$svc" 2>/dev/null || echo "missing")
      if [ "$state" = "running" ]; then
        log "$svc running after image rebuild"
        return 0
      fi
    else
      log "No images found for $svc to remove"
    fi
  else
    log "$svc not in ALLOW_DESTROY; skipping destructive steps"
  fi

  log "Heal attempts for $svc exhausted — manual intervention required"
  return 1
}

# Iterate all services from docker compose
services=$($DC_COMMAND config --services 2>/dev/null || true)
if [ -n "$services" ]; then
  for s in $services; do
    heal_service "$s" || log "Service $s failed to heal"
  done
else
  log "No services found from 'docker compose config --services'"
fi

log "Self-heal complete"
