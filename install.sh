#!/bin/bash
set -e

echo "----------------------------------------"
echo " Raspberry Pi Docker Earning Appliance"
echo " Honeygain + Pawns + Watchdog + Dashboard"
echo "----------------------------------------"

###############################################
# 0. PROMPTS (CREDENTIALS)
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

###############################################
# 1. SYSTEM PREP
###############################################

sudo apt update && sudo apt upgrade -y
sudo apt install -y jq ca-certificates curl gnupg

###############################################
# 2. INSTALL DOCKER
###############################################

curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"

###############################################
# 3. OPTIONAL: INSTALL TAILSCALE
###############################################

if [[ "$INSTALL_TAILSCALE" =~ ^[Yy]$ ]]; then
  echo "[*] Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
  echo ""
  echo "----------------------------------------"
  echo " Tailscale installed."
  echo " Run: sudo tailscale up"
  echo " to authenticate and enable remote access."
  echo "----------------------------------------"
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
SERVICES="honeygain pawns watchtower dozzle glances dashboard"

echo "[watchdog] Starting watchdog loop..."

while true; do
  if ! docker ps >/dev/null 2>&1; then
    echo "[watchdog] WARNING: docker ps failed. Docker daemon may be unhealthy."
  else
    for S in $SERVICES; do
      if ! docker ps --format '{{.Names}}' | grep -q "^${S}\$"; then
        echo "[watchdog] Service ${S} not running, attempting to start..."
        docker start "${S}" 2>/dev/null || docker restart "${S}" 2>/dev/null || true
      fi
    done
  fi
  sleep "${INTERVAL}"
done
EOF

chmod +x watchdog.sh

###############################################
# 7. CREATE DASHBOARD HTML
###############################################

mkdir -p dashboard

cat > dashboard/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Pi Earning Appliance Dashboard</title>
  <style>
    body { font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #050816; color: #f9fafb; margin: 0; padding: 24px; }
    h1 { margin-top: 0; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 16px; }
    .card { background: #0b1020; border-radius: 10px; padding: 16px 20px; box-shadow: 0 0 0 1px #1f2937; }
    .tag { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: 12px; background: #111827; margin-right: 6px; }
    .tag-ok { color: #4ade80; }
    .tag-warn { color: #facc15; }
    .tag-err { color: #f97373; }
    code { background: #111827; padding: 2px 4px; border-radius: 4px; font-size: 13px; }
    a { color: #60a5fa; text-decoration: none; }
    a:hover { text-decoration: underline; }
    ul { padding-left: 18px; }
  </style>
</head>
<body>
  <h1>Raspberry Pi Earning Appliance</h1>
  <p>Honeygain • Pawns • Watchtower • Watchdog • Dozzle • Glances</p>

  <div class="grid">
    <div class="card">
      <h2>Services</h2>
      <p><span class="tag tag-ok">●</span> Honeygain</p>
      <p><span class="tag tag-ok">●</span> Pawns</p>
      <p><span class="tag tag-ok">●</span> Watchtower (auto-update)</p>
      <p><span class="tag tag-ok">●</span> Watchdog (self-healing)</p>
      <p><span class="tag tag-ok">●</span> Dozzle (logs)</p>
      <p><span class="tag tag-ok">●</span> Glances (system metrics)</p>
    </div>

    <div class="card">
      <h2>Monitoring & Logs</h2>
      <p><strong>Dashboard (this page):</strong><br>
        <code>http://&lt;PI-IP&gt;:8088</code></p>
      <p><strong>Logs (Dozzle):</strong><br>
        <code>http://&lt;PI-IP&gt;:9999</code></p>
      <p><strong>System Monitor (Glances):</strong><br>
        <code>http://&lt;PI-IP&gt;:61208</code></p>
    </div>

    <div class="card">
      <h2>First‑Run Checklist</h2>
      <ul>
        <li>Open <code>http://&lt;PI-IP&gt;:8088</code> — see this dashboard.</li>
        <li>Open <code>http://&lt;PI-IP&gt;:9999</code> — confirm Honeygain & Pawns logs show activity.</li>
        <li>Open <code>http://&lt;PI-IP&gt;:61208</code> — confirm CPU, RAM, and temp look reasonable.</li>
        <li>Run <code>docker ps</code> via SSH — all services should be <em>Up</em>.</li>
      </ul>
    </div>

    <div class="card">
      <h2>Diagnostics</h2>
      <ul>
        <li>If a service stops, watchdog will attempt to restart it automatically.</li>
        <li>Check Dozzle for errors in Honeygain or Pawns logs.</li>
        <li>If Docker itself is unhealthy, reboot the Pi and re‑run <code>docker ps</code>.</li>
        <li>Use <code>docker logs &lt;service&gt;</code> for deeper debugging.</li>
      </ul>
    </div>

    <div class="card">
      <h2>Remote Access (Optional)</h2>
      <p>With Tailscale installed on the Pi:</p>
      <p><code>sudo tailscale up</code></p>
      <p>Then use your Tailscale IP:</p>
      <p><code>http://100.x.x.x:8088</code> (Dashboard)<br>
         <code>http://100.x.x.x:9999</code> (Logs)<br>
         <code>http://100.x.x.x:61208</code> (System)</p>
    </div>
  </div>
</body>
</html>
EOF

###############################################
# 8. DEPLOY DOCKER COMPOSE STACK
###############################################

echo "[*] Deploying Docker Compose stack..."

sudo docker compose down || true
sudo docker compose up -d

echo "----------------------------------------"
echo " Deployment complete!"
echo " Dashboard: http://<PI-IP>:8088"
echo " Logs:      http://<PI-IP>:9999"
echo " System:    http://<PI-IP>:61208"
echo "----------------------------------------"
