- Update the installer to auto‑detect the username
- Make the systemd file dynamic
- Add a post‑install verification step
- Add colored success/failure output
# Detect current username
USERNAME=$(whoami)
PROJECT_DIR="/home/$USERNAME/Raspberry-PI-docker-Earning"

info "Detected username: $USERNAME"
info "Project directory: $PROJECT_DIR"
#!/bin/bash
set -e

echo "----------------------------------------"
echo " Raspberry Pi Docker Earning Appliance"
echo "----------------------------------------"

###############################################
# 0. PROMPTS
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
# 1. SYSTEM PREP
###############################################

sudo apt update && sudo apt upgrade -y
sudo apt install -y jq ca-certificates curl gnupg netcat-openbsd

###############################################
# 2. INSTALL DOCKER
###############################################

curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"

###############################################
# 3. OPTIONAL: INSTALL TAILSCALE
###############################################

if [[ "$INSTALL_TAILSCALE" =~ ^[Yy]$ ]]; then
  curl -fsSL https://tailscale.com/install.sh | sh
  echo ""
  echo "Tailscale installed. Run 'sudo tailscale up' to authenticate."
  echo ""
fi

###############################################
# 4. ENABLE X86 EMULATION
###############################################

sudo docker run --privileged --rm tonistiigi/binfmt --install all

###############################################
# 5. WRITE .env FILE
###############################################

cat > .env <<EOF
HG_EMAIL=$HG_EMAIL
HG_PASSWORD=$HG_PASSWORD
PAWNS_EMAIL=$PAWNS_EMAIL
PAWNS_PASSWORD=$PAWNS_PASSWORD
EOF

###############################################
# 6. CREATE WATCHDOG SCRIPT
###############################################

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

###############################################
# 7. CREATE DIAGNOSTICS SERVER
###############################################

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

###############################################
# 8. CREATE DASHBOARD
###############################################

mkdir -p dashboard

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

###############################################
# 9. HANDLE WATCHDOG MODE
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

  # Remove Docker watchdog from stack.yml
  sed -i '/watchdog:/,/entrypoint:/d' stack.yml
else
  info "Using Docker-based watchdog"
fi
###############################################
# 10. DEPLOY STACK
###############################################

sudo docker compose down || true
sudo docker compose up -d
###############################################
# 11. POST-INSTALL VERIFICATION
###############################################

info "Running post-install verification..."

# Check Docker
if docker ps >/dev/null 2>&1; then
  ok "Docker is running"
else
  err "Docker is NOT running"
fi

# Check containers
REQUIRED_CONTAINERS="honeygain pawns watchtower dozzle glances dashboard diagnostics"

for C in $REQUIRED_CONTAINERS; do
  if docker ps --format '{{.Names}}' | grep -q "^${C}$"; then
    ok "Container running: $C"
  else
    warn "Container NOT running: $C"
  fi
done

# Check watchdog mode
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
