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

if [ ! -f "stack.yml" ] && [ ! -f "compose.yml" ]; then
  err "No compose file found. Run this installer from the project root:"
  echo "  cd ~/Raspberry-PI-docker-Earning"
  exit 1
fi

if [ -f "stack.yml" ] && [ ! -f "compose.yml" ]; then
  warn "Renaming stack.yml → compose.yml"
  mv stack.yml compose.yml
  ok "Renamed to compose.yml"
fi

if [ ! -f "compose.yml" ]; then
  err "compose.yml missing — cannot continue"
  exit 1
fi

###############################################
# DOCKER + COMPOSE
###############################################

info "Checking Docker..."

if ! command -v docker >/dev/null 2>&1; then
    warn "Docker not installed — installing"
    curl -fsSL https://get.docker.com | sudo sh
    ok "Docker installed"
else
    ok "Docker already installed"
fi

if ! systemctl is-active --quiet docker; then
    warn "Docker not running — starting"
    sudo systemctl start docker
fi

if ! groups $USERNAME | grep -q docker; then
    warn "Adding user to docker group"
    sudo usermod -aG docker $USERNAME
    info "Log out and back in for group changes"
fi

info "Checking Docker Compose v2..."

if ! docker compose version >/dev/null 2>&1; then
    warn "Installing docker-compose-plugin"
    sudo apt update -y
    sudo apt install -y docker-compose-plugin
fi

docker compose version >/dev/null 2>&1 || {
    err "Docker Compose v2 unavailable"
    exit 1
}

ok "Docker Compose v2 ready"

###############################################
# DOCKER PERMISSION SELF-HEALING
###############################################

info "Verifying Docker permissions..."

if ! docker ps >/dev/null 2>&1; then
    warn "Docker access denied — applying fixes..."

    # Add user to docker group if missing
    if ! groups $USERNAME | grep -q docker; then
        info "Adding $USERNAME to docker group..."
        sudo usermod -aG docker "$USERNAME"
        sg docker -c "echo '[✔] Docker group applied'"
    fi

    # Fix socket permissions if still failing
    if ! docker ps >/dev/null 2>&1; then
        info "Fixing Docker socket permissions..."
        sudo chmod 666 /var/run/docker.sock
    fi
fi

# Final verification
if docker ps >/dev/null 2>&1; then
    ok "Docker permissions OK"
else
    err "Docker still inaccessible — reboot required"
    exit 1
fi

###############################################
# DASHBOARD DIRECTORY
###############################################

mkdir -p dashboard

if [ ! -f "dashboard/index.html" ]; then
  warn "dashboard/index.html missing — creating placeholder"
  echo "<h1>Dashboard Placeholder</h1>" > dashboard/index.html
fi

ok "Pre-flight checks complete"

###############################################
# 1. CREDENTIAL SETUP (MODERNIZED)
###############################################

echo ""
info "Setting up service credentials..."

require_input() {
  local prompt="$1"
  local varname="$2"
  local value=""
  while true; do
    read -p "$prompt" value
    if [ -n "$value" ]; then
      eval "$varname=\"$value\""
      break
    else
      warn "Value cannot be empty."
    fi
  done
}

require_password() {
  local prompt="$1"
  local varname="$2"
  local value=""
  while true; do
    read -s -p "$prompt" value
    echo ""
    if [ -n "$value" ]; then
      eval "$varname=\"$value\""
      break
    else
      warn "Password cannot be empty."
    fi
  done
}

echo ""
require_input    "Enter Honeygain email: "      HONEYGAIN_EMAIL
require_password "Enter Honeygain password: "   HONEYGAIN_PASSWORD
echo ""
require_input    "Enter Pawns email: "          PAWNS_EMAIL
require_password "Enter Pawns password: "       PAWNS_PASSWORD
echo ""
read -p "Install Tailscale for remote access? (y/N): " INSTALL_TAILSCALE
echo ""
read -p "Use systemd watchdog instead of Docker watchdog? (y/N): " USE_SYSTEMD
echo ""

###############################################
# 2. SYSTEM PREP
###############################################

info "Updating system..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y jq ca-certificates curl gnupg busybox
ok "System updated"

###############################################
# 3. OPTIONAL: TAILSCALE
###############################################

if [[ "$INSTALL_TAILSCALE" =~ ^[Yy]$ ]]; then
  info "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
  ok "Tailscale installed"
fi

###############################################
# 4. ENABLE X86 EMULATION
###############################################

info "Enabling x86 emulation..."
sudo docker run --privileged --rm tonistiigi/binfmt --install all
ok "x86 emulation enabled"

###############################################
# 5. WRITE .env FILE
###############################################

info "Writing .env..."
cat > .env <<EOF
HONEYGAIN_EMAIL=$HONEYGAIN_EMAIL
HONEYGAIN_PASSWORD=$HONEYGAIN_PASSWORD

PAWNS_EMAIL=$PAWNS_EMAIL
PAWNS_PASSWORD=$PAWNS_PASSWORD
EOF
ok ".env created"

###############################################
# 6. CREATE DIAGNOSTICS CONTAINER FOLDER
###############################################

info "Creating diagnostics container..."

mkdir -p diagnostics

cat > diagnostics/diagnostics.sh <<'EOF'
#!/bin/sh

PORT=7000

while true; do
  {
    echo "HTTP/1.1 200 OK"
    echo "Content-Type: application/json"
    echo ""

    CPU=$(uptime | awk -F'load average:' '{print $2}')
    RAM=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
    DISK=$(df -h / | awk 'NR==2 {print $5}')
    TEMP=$(vcgencmd measure_temp 2>/dev/null || echo "N/A")
    UPTIME=$(uptime -p)

    echo "{"
    echo "\"docker_running\": \"$(docker ps >/dev/null 2>&1 && echo yes || echo no)\","

    echo "\"containers\": {"
    for S in honeygain pawns watchtower dozzle glances dashboard diagnostics; do
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

    echo "\"system\": {"
    echo "\"cpu_load\": \"$CPU\","
    echo "\"ram\": \"$RAM\","
    echo "\"disk\": \"$DISK\","
    echo "\"temp\": \"$TEMP\","
    echo "\"uptime\": \"$UPTIME\""
    echo "}"

    echo "}"
  } | /bin/busybox nc -l -p $PORT -k
done
EOF

chmod +x diagnostics/diagnostics.sh

cat > diagnostics/Dockerfile <<'EOF'
FROM alpine:latest
RUN apk add --no-cache busybox docker-cli
COPY diagnostics.sh /diagnostics.sh
ENTRYPOINT ["/bin/sh", "/diagnostics.sh"]
EOF

ok "Diagnostics container created"

###############################################
# 7. REPAIR COMPOSE.YML
###############################################

info "Repairing compose.yml..."

if ! grep -q "diagnostics:" compose.yml; then
cat >> compose.yml <<EOF

  diagnostics:
    build: ./diagnostics
    container_name: diagnostics
    restart: unless-stopped
    ports:
      - "7000:7000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
EOF
fi

ok "compose.yml repaired"

###############################################
# 8. DEPLOY STACK
###############################################

info "Deploying stack..."
docker compose down || true
docker compose up -d
ok "Stack deployed"

###############################################
# 9. POST-INSTALL VERIFICATION
###############################################

info "Verifying..."

docker ps >/dev/null 2>&1 && ok "Docker running"

for C in honeygain pawns watchtower dozzle glances dashboard diagnostics; do
  if docker ps --format '{{.Names}}' | grep -q "^${C}$"; then
    ok "Container running: $C"
  else
    warn "Container NOT running: $C"
  fi
done

ok "Verification complete"

echo "----------------------------------------"
echo " Deployment complete!"
echo " Dashboard: http://<PI-IP>:8088"
echo " Diagnostics: http://<PI-IP>:7000"
echo "----------------------------------------"
