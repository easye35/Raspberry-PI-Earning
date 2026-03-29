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
# 3. ENABLE X86 EMULATION
###############################################

sudo docker run --privileged --rm tonistiigi/binfmt --install all

###############################################
# 4. WRITE .env FILE
###############################################

cat > .env <<EOF
HG_EMAIL=$HG_EMAIL
HG_PASSWORD=$HG_PASSWORD
PAWNS_EMAIL=$PAWNS_EMAIL
PAWNS_PASSWORD=$PAWNS_PASSWORD
EOF

###############################################
# 5. CREATE WATCHDOG SCRIPT
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
# 6. CREATE DASHBOARD HTML
###############################################

mkdir -p dashboard

cat > dashboard/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Pi Earning Appliance Dashboard</title>
  <style>
    body { font-family: system-ui, sans-serif; background: #0b1020; color: #f5f5f5; margin: 0; padding: 20px; }
    h1 { margin-top: 0; }
    .card { background: #151a2c; border-radius: 8px; padding: 16px 20px; margin-bottom: 16px; box-shadow: 0 0 0 1px #222842; }
    a { color: #61dafb; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 16px; }
    .tag { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: 12px; background: #1f253a; margin-right: 6px; }
    .tag-ok { color: #4ade80; }
  </style>
</head>
<body>
  <h1>Raspberry Pi Earning Appliance</h1>
  <p>Honeygain • Pawns • Watchtower • Watchdog • Monitoring</p>

  <div class="grid">
    <div class="card">
      <h2>Services</h2>
      <p><span class="tag tag-ok">●</span> Honeygain</p>
      <p><span class="tag tag-ok">●</span> Pawns</p>
      <p><span class="tag tag-ok">●</span> Watchtower</p>
      <p><span class="tag tag-ok">●</span> Watchdog</p>
      <p><span class="tag tag-ok">●</span> Dozzle</p>
      <p><span class="tag tag-ok">●</span> Glances</p>
    </div>

    <div class="card">
      <h2>Monitoring</h2>
      <p><strong>Logs (Dozzle):</strong><br>
        <code>http://&lt;PI-IP&gt;:9999</code></p>
      <p><strong>System Monitor (Glances):</strong><br>
        <code>http://&lt;PI-IP&gt;:61208</code></p>
    </div>

    <div class="card">
      <h2>Remote Access</h2>
      <p>Install Tailscale:</p>
      <p><code>curl -fsSL https://tailscale.com/install.sh | sh</code><br>
         <code>sudo tailscale up</code></p>
      <p>Then open:</p>
      <p><code>http://100.x.x.x:8088</code> (Dashboard)<br>
         <code>http://100.x.x.x:9999</code> (Logs)<br>
         <code>http://100.x.x.x:61208</code> (System)</p>
    </div>
  </div>
</body>
</html>
EOF

###############################################
# 7. DEPLOY DOCKER COMPOSE STACK
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
