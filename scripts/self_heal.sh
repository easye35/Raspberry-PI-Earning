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

log() { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"; }

if ! command -v docker >/dev/null 2>&1; then
  log "docker CLI not found. Install Docker and re-run."
  exit 1
fi

cd "$ROOT"

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

log "Self-heal complete"
