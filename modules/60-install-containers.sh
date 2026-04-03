#!/usr/bin/env bash
set -Eeuo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULE_DIR/logging.sh"
source "$MODULE_DIR/utils.sh"

log::section "Container Suite Installation"

###############################################################################
# Determine data root (HDD-aware)
###############################################################################

DATA_ROOT="/mnt/storage"
if ! mountpoint -q /mnt/storage 2>/dev/null; then
  log::warn "/mnt/storage is not mounted — falling back to /opt/earnbox"
  DATA_ROOT="/opt/earnbox"
fi

log::info "Using data root: $DATA_ROOT"

sudo mkdir -p "$DATA_ROOT/config" "$DATA_ROOT/dashboard" "$DATA_ROOT/logs"

###############################################################################
# Prompt helpers
###############################################################################

prompt_yes_no() {
  local prompt="$1"
  local default="${2:-Y}"
  local answer

  read -r -p "$prompt " answer || true
  answer="${answer:-$default}"
  case "$answer" in
    [Yy]*) return 0 ;;
    *)     return 1 ;;
  esac
}

prompt_line() {
  local prompt="$1"
  local var
  read -r -p "$prompt " var || true
  printf '%s' "$var"
}

###############################################################################
# Flags for enabled services
###############################################################################

ENABLE_EARNAPP=false
ENABLE_HONEYGAIN=false
ENABLE_PAWNS=false
ENABLE_PACKETSTREAM=false
ENABLE_REPOCKET=false
ENABLE_IPROYAL=false

###############################################################################
# EarnApp
###############################################################################

if prompt_yes_no "Install EarnApp? (Y/n):" "Y"; then
  ENABLE_EARNAPP=true
  log::ok "EarnApp will be installed."
else
  log::warn "EarnApp installation skipped."
fi

###############################################################################
# Honeygain
###############################################################################

if prompt_yes_no "Install Honeygain? (Y/n):" "Y"; then
  ENABLE_HONEYGAIN=true
  log::ok "Honeygain will be installed."
else
  log::warn "Honeygain installation skipped."
fi

###############################################################################
# Pawns.app
###############################################################################

PAWNS_EMAIL="$(prompt_line 'Enter your Pawns email (leave blank to skip Pawns):')"

if [[ -n "$PAWNS_EMAIL" ]]; then
  PAWNS_PASSWORD="$(prompt_line 'Enter your Pawns password:')"
  PAWNS_DEVICE_NAME="$(prompt_line 'Enter a device name (default: earnbox):')"
  PAWNS_DEVICE_NAME="${PAWNS_DEVICE_NAME:-earnbox}"

  ENABLE_PAWNS=true
  log::ok "Pawns will be installed as device '$PAWNS_DEVICE_NAME'."

  cat <<EOF | sudo tee "$DATA_ROOT/config/pawns.env" >/dev/null
PAWNS_EMAIL=$PAWNS_EMAIL
PAWNS_PASSWORD=$PAWNS_PASSWORD
PAWNS_DEVICE_NAME=$PAWNS_DEVICE_NAME
EOF
else
  log::warn "Pawns installation skipped."
fi

###############################################################################
# PacketStream
###############################################################################

PACKETSTREAM_TOKEN="$(prompt_line 'Enter your PacketStream token (leave blank to skip PacketStream):')"

if [[ -n "$PACKETSTREAM_TOKEN" ]]; then
  ENABLE_PACKETSTREAM=true
  log::ok "PacketStream will be installed."

  cat <<EOF | sudo tee "$DATA_ROOT/config/packetstream.env" >/dev/null
PS_TOKEN=$PACKETSTREAM_TOKEN
EOF
else
  log::warn "PacketStream installation skipped."
fi

###############################################################################
# Repocket
###############################################################################

REPOCKET_TOKEN="$(prompt_line 'Enter your Repocket token (leave blank to skip Repocket):')"

if [[ -n "$REPOCKET_TOKEN" ]]; then
  ENABLE_REPOCKET=true
  log::ok "Repocket will be installed."

  cat <<EOF | sudo tee "$DATA_ROOT/config/repocket.env" >/dev/null
REPOCKET_TOKEN=$REPOCKET_TOKEN
EOF
else
  log::warn "Repocket installation skipped."
fi

###############################################################################
# IPRoyal Pawns
###############################################################################

IPROYAL_API_KEY="$(prompt_line 'Enter your IPRoyal Pawns API key (leave blank to skip IPRoyal):')"

if [[ -n "$IPROYAL_API_KEY" ]]; then
  ENABLE_IPROYAL=true
  log::ok "IPRoyal Pawns will be installed."

  cat <<EOF | sudo tee "$DATA_ROOT/config/iproyal.env" >/dev/null
IPROYAL_API_KEY=$IPROYAL_API_KEY
EOF
else
  log::warn "IPRoyal Pawns installation skipped."
fi

###############################################################################
# Generate docker-compose.yml dynamically
###############################################################################

COMPOSE_PATH="$(cd "$MODULE_DIR/.." && pwd)/docker-compose.yml"
log::step "Generating docker-compose.yml at $COMPOSE_PATH"

{
  echo 'version: "3.8"'
  echo
  echo "services:"

  # Management stack (always)
  cat <<EOF
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ${DATA_ROOT}/portainer:/data

  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    command: --cleanup --schedule "0 0 * * *"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

  netdata:
    image: netdata/netdata:stable
    container_name: netdata
    restart: unless-stopped
    hostname: earnbox
    ports:
      - "19999:19999"
    cap_add:
      - SYS_PTRACE
    security_opt:
      - apparmor:unconfined
    volumes:
      - netdata-config:/etc/netdata
      - netdata-lib:/var/lib/netdata
      - netdata-cache:/var/cache/netdata
      - /etc/passwd:/host/etc/passwd:ro
      - /etc/group:/host/etc/group:ro
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /etc/os-release:/host/etc/os-release:ro

  dashboard:
    image: nginx:alpine
    container_name: earnbox-dashboard
    restart: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - ${DATA_ROOT}/dashboard:/usr/share/nginx/html:ro

  diagnostics:
    image: alpine:latest
    container_name: earnbox-diagnostics
    restart: unless-stopped
    command: ["sh", "-c", "while true; do sleep 3600; done"]
    volumes:
      - ${DATA_ROOT}/logs:/logs
      - /var/run/docker.sock:/var/run/docker.sock
      - /:/host:ro
EOF

  # EarnApp
  if [[ "$ENABLE_EARNAPP" == true ]]; then
    cat <<EOF

  earnapp:
    image: fazalfarhan01/earnapp:latest
    container_name: earnapp
    restart: unless-stopped
    network_mode: bridge
    volumes:
      - ${DATA_ROOT}/earnapp:/etc/earnapp
EOF
  fi

  # Honeygain
  if [[ "$ENABLE_HONEYGAIN" == true ]]; then
    cat <<EOF

  honeygain:
    image: honeygain/honeygain:latest
    container_name: honeygain
    restart: unless-stopped
    network_mode: bridge
    command: ["-device", "earnbox", "-tou-accept"]
EOF
  fi

  # Pawns
  if [[ "$ENABLE_PAWNS" == true ]]; then
    cat <<EOF

  pawns:
    image: iproyal/pawns:latest
    container_name: pawns
    restart: unless-stopped
    env_file:
      - ${DATA_ROOT}/config/pawns.env
EOF
  fi

  # PacketStream
  if [[ "$ENABLE_PACKETSTREAM" == true ]]; then
    cat <<EOF

  packetstream:
    image: packetstream/psclient:latest
    container_name: packetstream
    restart: unless-stopped
    env_file:
      - ${DATA_ROOT}/config/packetstream.env
EOF
  fi

  # Repocket
  if [[ "$ENABLE_REPOCKET" == true ]]; then
    cat <<EOF

  repocket:
    image: repocket/repocket:latest
    container_name: repocket
    restart: unless-stopped
    env_file:
      - ${DATA_ROOT}/config/repocket.env
EOF
  fi

  # IPRoyal Pawns
  if [[ "$ENABLE_IPROYAL" == true ]]; then
    cat <<EOF

  iproyal_pawns:
    image: iproyal/pawns:latest
    container_name: iproyal-pawns
    restart: unless-stopped
    env_file:
      - ${DATA_ROOT}/config/iproyal.env
EOF
  fi

  # Volumes
  cat <<EOF

volumes:
  netdata-config:
  netdata-lib:
  netdata-cache:
EOF

} | sudo tee "$COMPOSE_PATH" >/dev/null

log::ok "docker-compose.yml generated."

###############################################################################
# Ensure dashboard assets exist
###############################################################################

if [[ ! -f "$DATA_ROOT/dashboard/index.html" ]]; then
  log::step "Seeding default dashboard assets."
  sudo mkdir -p "$DATA_ROOT/dashboard"
  sudo tee "$DATA_ROOT/dashboard/index.html" >/dev/null <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Earnbox Dashboard</title>
  <style>
    body {
      margin: 0;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: radial-gradient(circle at top, #1f2933, #020617);
      color: #e5e7eb;
    }
    .wrap {
      max-width: 1100px;
      margin: 0 auto;
      padding: 2rem;
    }
    h1 {
      font-size: 2rem;
      margin-bottom: 0.5rem;
    }
    .subtitle {
      color: #9ca3af;
      margin-bottom: 2rem;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 1.5rem;
    }
    .card {
      background: rgba(15, 23, 42, 0.9);
      border-radius: 0.75rem;
      padding: 1.25rem 1.5rem;
      box-shadow: 0 18px 45px rgba(0, 0, 0, 0.45);
      border: 1px solid rgba(148, 163, 184, 0.25);
      backdrop-filter: blur(10px);
    }
    .card h2 {
      font-size: 1rem;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: #9ca3af;
      margin: 0 0 0.75rem;
    }
    .metric {
      font-size: 1.8rem;
      font-weight: 600;
    }
    .metric span {
      font-size: 0.9rem;
      color: #9ca3af;
      margin-left: 0.25rem;
    }
    .status-dot {
      display: inline-block;
      width: 10px;
      height: 10px;
      border-radius: 999px;
      margin-right: 0.4rem;
    }
    .status-up { background: #22c55e; }
    .status-down { background: #ef4444; }
    .status-warn { background: #eab308; }
    .list {
      list-style: none;
      padding: 0;
      margin: 0.25rem 0 0;
      font-size: 0.9rem;
    }
    .list li {
      display: flex;
      justify-content: space-between;
      padding: 0.15rem 0;
      color: #d1d5db;
    }
    .pill {
      display: inline-flex;
      align-items: center;
      padding: 0.15rem 0.55rem;
      border-radius: 999px;
      font-size: 0.75rem;
      background: rgba(15, 118, 110, 0.2);
      color: #6ee7b7;
      border: 1px solid rgba(45, 212, 191, 0.4);
    }
    .footer {
      margin-top: 2rem;
      font-size: 0.8rem;
      color: #6b7280;
      text-align: right;
    }
  </style>
</head>
<body>
  <div class="wrap">
    <h1>Earnbox</h1>
    <div class="subtitle">Live view of your earning appliance — containers, health, and system status.</div>

    <div class="grid">
      <div class="card">
        <h2>System Health</h2>
        <div class="metric" id="sys-health">OK<span>overall</span></div>
        <ul class="list">
          <li><span>CPU Load</span><span id="cpu-load">–</span></li>
          <li><span>Memory</span><span id="mem-usage">–</span></li>
          <li><span>Disk</span><span id="disk-usage">–</span></li>
        </ul>
      </div>

      <div class="card">
        <h2>Containers</h2>
        <ul class="list" id="container-list">
          <li><span><span class="status-dot status-warn"></span>Loading…</span><span>–</span></li>
        </ul>
      </div>

      <div class="card">
        <h2>Earnings (Placeholder)</h2>
        <div class="metric">Soon<span>per day</span></div>
        <ul class="list">
          <li><span>EarnApp</span><span>–</span></li>
          <li><span>Honeygain</span><span>–</span></li>
          <li><span>Pawns / others</span><span>–</span></li>
        </ul>
      </div>

      <div class="card">
        <h2>Status</h2>
        <div class="pill" id="refresh-pill">Auto-refresh: 10s</div>
        <ul class="list">
          <li><span>Docker</span><span id="docker-status">–</span></li>
          <li><span>External storage</span><span id="storage-status">–</span></li>
          <li><span>Last update</span><span id="last-update">–</span></li>
        </ul>
      </div>
    </div>

    <div class="footer">
      Earnbox dashboard — static UI wired to your diagnostics in the next iteration.
    </div>
  </div>

  <script>
    // Placeholder auto-refresh tick; you can later wire this to a JSON endpoint
    function tick() {
      const now = new Date().toLocaleTimeString();
      document.getElementById('last-update').textContent = now;
    }
    setInterval(tick, 10000);
    tick();
  </script>
</body>
</html>
HTML
fi

###############################################################################
# Start containers
###############################################################################

log::step "Pulling and starting containers via docker compose"

COMPOSE_DIR="$(cd "$MODULE_DIR/.." && pwd)"
cd "$COMPOSE_DIR"

sudo DATA_ROOT="$DATA_ROOT" docker compose pull
sudo DATA_ROOT="$DATA_ROOT" docker compose up -d

log::success_block "Container suite installed and started."
