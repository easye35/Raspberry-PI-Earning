#!/bin/bash
set -e

###############################################
# COLORS & STATUS HELPERS
###############################################

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

ok()    { echo -e "${GREEN}[✔]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[!]${RESET} $1"; }
err()   { echo -e "${RED}[✘]${RESET} $1"; }
info()  { echo -e "${BLUE}[*]${RESET} $1"; }

###############################################
# HEADER
###############################################

echo "----------------------------------------"
echo " Raspberry Pi Docker Earning Appliance"
echo "----------------------------------------"

###############################################
# 0. DETECT USER + PROJECT PATH
###############################################

USERNAME=$(whoami)
PROJECT_DIR="/home/$USERNAME/Raspberry-PI-docker-Earning"

info "Detected username: $USERNAME"
info "Project directory: $PROJECT_DIR"

###############################################
# PRE-FLIGHT CHECKS
###############################################

info "Running pre-flight checks..."

# Ensure script is run from project directory
if [ ! -f "stack.yml" ] && [ ! -f "compose.yml" ]; then
  err "No compose file found. Run this installer from the project root:"
  echo "  cd ~/Raspberry-PI-docker-Earning"
  exit 1
fi

# Normalize compose file name
if [ -f "stack.yml" ] && [ ! -f "compose.yml" ]; then
  warn "Renaming stack.yml → compose.yml for Docker Compose v2 compatibility"
  mv stack.yml compose.yml
  ok "Compose file renamed to compose.yml"
fi

# Ensure compose.yml exists
if [ ! -f "compose.yml" ]; then
  err "compose.yml missing — cannot continue"
  exit 1
fi

###############################################
# FIXED: AUTO-INSTALL DOCKER COMPOSE V2
###############################################

info "Checking for Docker Compose v2..."

if ! docker compose version >/dev/null 2>&1; then
    warn "Docker Compose v2 not found — installing now"

    sudo apt update -y
    sudo apt install -y docker-compose-plugin

    if docker compose version >/dev/null 2>&1; then
        ok "Docker Compose v2 installed successfully"
    else
        err "Failed to install Docker Compose v2 — cannot continue"
        exit 1
    fi
else
    ok "Docker Compose v2 already installed"
fi

# Set compose command
COMPOSE_CMD="docker compose"

###############################################
# Ensure dashboard directory exists
###############################################

if [ ! -d "dashboard" ]; then
  warn "dashboard/ directory missing — creating it now"
  mkdir -p dashboard
fi

# Ensure index.html exists
if [ ! -f "dashboard/index.html" ]; then
  warn "dashboard/index.html missing — creating placeholder"
  echo "<h1>Dashboard Placeholder</h1>" > dashboard/index.html
fi

# Ensure Docker is installed
if ! command -v docker >/dev/null 2>&1; then
  warn "Docker not installed — will install during setup"
else
  ok "Docker is installed"
fi

ok "Pre-flight checks complete"

###############################################
# 1. PROMPTS
###############################################

echo ""
read -p "Enter Honeygain email: " HG_EMAIL
read -s -p "Enter Honeygain password: " HG_PASSWORD
echo ""
read -p "Enter Pawns email: " PAWNS_EMAIL
read -s -p "Enter Pawns password: " PAWNS_PASSWORD
echo ""
read -p "Install Tailscale for remote access? (y/N): " INSTALL_TAILSCALE
echo ""
read -p "Use systemd watchdog instead of Docker watchdog? (y/N): " USE_SYSTEMD
echo ""

###############################################
# 2. SYSTEM PREP
###############################################

info "Updating system packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y jq ca-certificates curl gnupg netcat-openbsd
ok "System updated"

###############################################
# 3. INSTALL DOCKER
###############################################

info "Installing Docker..."
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USERNAME"
ok "Docker installed"

###############################################
# 4. OPTIONAL: INSTALL TAILSCALE
###############################################

if [[ "$INSTALL_TAILSCALE" =~ ^[Yy]$ ]]; then
  info "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
  ok "Tailscale installed (run 'sudo tailscale up' to authenticate)"
fi

###############################################
# 5. ENABLE X86 EMULATION
###############################################

info "Enabling x86 emulation..."
sudo docker run --privileged --rm tonistiigi/binfmt --install all
ok "x86 emulation enabled"

###############################################
# 6. WRITE .env FILE
###############################################

info "Writing .env file..."
cat > .env <<EOF
HG_EMAIL=$HG_EMAIL
HG_PASSWORD=$HG_PASSWORD
PAWNS_EMAIL=$PAWNS_EMAIL
PAWNS_PASSWORD=$PAWNS_PASSWORD
EOF
ok ".env created"

###############################################
# 7. CREATE WATCHDOG SCRIPT
###############################################

info "Creating watchdog script..."

cat > watchdog.sh <<'EOF'
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
EOF

chmod +x watchdog.sh
ok "watchdog.sh created"

###############################################
# 8. CREATE DIAGNOSTICS SERVER
###############################################

info "Creating diagnostics server..."

cat > diagnostics-server.sh <<'EOF'
#!/bin/sh

while true; do
  {
    echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{"

    echo "\"docker_running\": \"$(docker ps >/dev/null 2>&1 && echo yes || echo no)\","

    echo "\"containers\": {"
    for S in honeygain pawns watchtower dozzle glances dashboard watchdog diagnostics; do
      RUNNING=$(docker ps --format '{{.Names}}' | grep -q "^${S}$" && echo running || echo stopped)
      echo "\"$S\": \"$RUNNING\","
    done
    echo "\"_end\": \"\"},"

    echo "\"healthchecks\": {"
    for S in honeygain pawns; do
      STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$S" 2>/dev/null)
      echo "\"$S\": \"$STATUS\","
    done
    echo "\"_end\": \"\"},"

    CPU=$(uptime | awk -F'load average:' '{print $2}')
    RAM=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
    DISK=$(df -h / | awk 'NR==2 {print $5}')
    TEMP=$(vcgencmd measure_temp 2>/dev/null || echo "N/A")

    echo "\"system\": {"
    echo "\"cpu_load\": \"$CPU\","
    echo "\"ram\": \"$RAM\","
    echo "\"disk\": \"$DISK\","
    echo "\"temp\": \"$TEMP\""
    echo "}"

    echo "}"
  } | nc -l -p 7000 -q 1
done
EOF

chmod +x diagnostics-server.sh
ok "diagnostics-server.sh created"

###############################################
# 9. CREATE DASHBOARD
###############################################

info "Ensuring dashboard directory exists..."
mkdir -p dashboard

info "Writing dashboard/index.html..."
cat > dashboard/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Pi Earning Appliance Dashboard</title>
  <style>
    body { font-family: system-ui, sans-serif; background: #050816; color: #f9fafb; padding: 24px; }
    .card { background:#0b1020; padding:16px; border-radius:10px; margin-bottom:16px; }
    button { padding:10px 18px; background:#2563eb; color:white; border:none; border-radius:6px; cursor:pointer; }
    pre { background:#0b1020; padding:16px; border-radius:8px; white-space:pre-wrap; }
  </style>
</head>
<body>

<h1>Raspberry Pi Earning Appliance</h1>

<button onclick="runDiagnostics()">Run Diagnostics</button>

<pre id="diag-output" style="display:none;"></pre>

<script>
function runDiagnostics() {
  const box = document.getElementById("diag-output");
  box.style.display = "block";
  box.textContent = "Running diagnostics...";

  fetch("http://" + window.location.hostname + ":7000")
    .then(r => r.json())
    .then(data => box.textContent = JSON.stringify(data, null, 2))
    .catch(err => box.textContent = "Error: " + err);
}
</script>

<div class="card">
  <h2>Quick Links</h2>
  <p>Logs: <code>http://&lt;PI-IP&gt;:9999</code></p>
  <p>System Monitor: <code>http://&lt;PI-IP&gt;:61208</code></p>
</div>

</body>
</html>
EOF

ok "Dashboard created"

###############################################
# REPAIR ROUTINES
###############################################

info "Running repair routines..."

# Fix misplaced index.html
if [ -f "index.html" ] && [ ! -f "dashboard/index.html" ]; then
  warn "Found index.html in project root — moving to dashboard/"
  mv index.html dashboard/
fi

# Fix missing dashboard block
if ! grep -q "dashboard:" compose.yml; then
  warn "Dashboard service missing — restoring it"

  cat >> compose.yml <<EOF

  dashboard:
    image: nginx:alpine
    container_name: dashboard
    restart: unless-stopped
    ports:
      - "8088:80"
    volumes:
      - ./dashboard:/usr/share/nginx/html:ro
EOF
fi

# Fix missing diagnostics block
if ! grep -q "diagnostics:" compose.yml; then
  warn "Diagnostics service missing — restoring it"

  cat >> compose.yml <<EOF

  diagnostics:
    image: alpine:latest
    container_name: diagnostics
    restart: unless-stopped
    ports:
      - "7000:7000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./diagnostics-server.sh:/diagnostics-server.sh:ro
    entrypoint: ["/bin/sh", "/diagnostics-server.sh"]
EOF
fi

ok "Repair routines complete"

###############################################
# 10. HANDLE WATCHDOG MODE
###############################################

if [[ "$USE_SYSTEMD" =~ ^[Yy]$ ]]; then
  info "Using systemd watchdog"

  mkdir -p systemd

  cat > systemd/pi-earning-watchdog.service <<EOF
[Unit]
Description=Raspberry Pi Earning Appliance Watchdog
After=docker.service
Requires=docker.service

[Service]
Type=simple
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/docker start watchdog
ExecStop=/usr/bin/docker stop watchdog
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  sudo cp systemd/pi-earning-watchdog.service /etc/systemd/system/
  sudo systemctl daemon-reload
  sudo systemctl enable pi-earning-watchdog
  sudo systemctl start pi-earning-watchdog

  ok "Systemd watchdog installed"

  sed -i '/watchdog:/,/entrypoint:/d' compose.yml
else
  info "Using Docker-based watchdog"
fi

###############################################
# 11. DEPLOY STACK
###############################################

info "Deploying Docker stack..."
$COMPOSE_CMD down || true
$COMPOSE_CMD up -d
ok "Stack deployed"

###############################################
# 12. POST-INSTALL VERIFICATION
###############################################

info "Running post-install verification..."

if docker ps >/dev/null 2>&1; then
  ok "Docker is running"
else
  err "Docker is NOT running"
fi

REQUIRED_CONTAINERS="honeygain pawns watchtower dozzle glances dashboard diagnostics"

for C in $REQUIRED_CONTAINERS; do
  if docker ps --format '{{.Names}}' | grep -q "^${C}$"; then
    ok "Container running: $C"
  else
    warn "Container NOT running: $C"
  fi
done

# Verify dashboard
if docker ps --format '{{.Names}}' | grep -q "^dashboard$"; then
  ok "Dashboard container running"
else
  err "Dashboard container NOT running — attempting repair"
  $COMPOSE_CMD up -d dashboard || err "Dashboard failed to start even after repair"
fi

# Verify watchdog
if [[ "$USE_SYSTEMD" =~ ^[Yy]$ ]]; then
  if systemctl is-active --quiet pi-earning-watchdog; then
    ok "Systemd watchdog active"
  else
    err "Systemd watchdog NOT running"
  fi
else
  if docker ps --format '{{.Names}}' | grep -q "^watchdog$"; then
    ok "Docker watchdog active"
  else
    err "Docker watchdog NOT running"
  fi
fi

ok "Verification complete"

echo "----------------------------------------"
echo " Deployment complete!"
echo " Dashboard: http://<PI-IP>:8088"
echo "----------------------------------------"
