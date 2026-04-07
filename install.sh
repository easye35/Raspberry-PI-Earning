#!/usr/bin/env bash
set -e

###############################################
#  EarnBox Appliance‑Grade Installer
###############################################

# --- Color Output ---
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; BLUE="\e[34m"; RESET="\e[0m"

info()  { echo -e "${BLUE}[INFO]${RESET} $1"; }
ok()    { echo -e "${GREEN}[OK]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $1"; }
err()   { echo -e "${RED}[ERROR]${RESET} $1"; exit 1; }

###############################################
# Correct User Detection (sudo‑safe)
###############################################

REAL_USER="${SUDO_USER:-$USER}"
info "Detected invoking user: $REAL_USER"

###############################################
# Docker Preflight + Auto‑Installer
###############################################

install_docker() {
  info "Installing Docker..."
  curl -fsSL https://get.docker.com | sudo sh || err "Docker installation failed."
  ok "Docker installed."
}

ensure_docker_group() {
  if groups "$REAL_USER" | grep -q '\bdocker\b'; then
    ok "User '$REAL_USER' already in docker group."
    return
  fi

  info "Adding '$REAL_USER' to docker group..."
  sudo usermod -aG docker "$REAL_USER"
  ok "User '$REAL_USER' added to docker group."

  info "Re-running script inside docker group as '$REAL_USER'..."
  exec sudo -u "$REAL_USER" sg docker "$0" "$@"
}

check_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    warn "Docker not found."
    install_docker
  else
    ok "Docker is installed."
  fi
}

check_compose() {
  if ! docker compose version >/dev/null 2>&1; then
    warn "Docker Compose v2 not found."
    info "Installing Docker Compose plugin..."
    sudo apt-get update -y
    sudo apt-get install -y docker-compose-plugin || err "Failed to install docker-compose-plugin."
  else
    ok "Docker Compose v2 is installed."
  fi
}

check_docker
check_compose
ensure_docker_group

ok "Docker environment ready."

###############################################
# Paths and Repo Setup
###############################################

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
REPO_ROOT="$SCRIPT_DIR"
DATA_ROOT="/mnt/storage"
COMPOSE_FILE="$REPO_ROOT/docker-compose.yml"

info "Repo root: $REPO_ROOT"
info "Data root: $DATA_ROOT"

###############################################
# Native EarnApp Installer (Official)
###############################################

EARNAPP_PAIR_URL=""

install_earnapp_native() {
  read -rp "Install EarnApp natively (official method)? (Y/n): " INSTALL_EARNAPP
  INSTALL_EARNAPP=${INSTALL_EARNAPP:-Y}

  if [[ ! "$INSTALL_EARNAPP" =~ ^[Yy]$ ]]; then
    warn "Skipping native EarnApp installation."
    return
  fi

  info "Downloading EarnApp installer..."
  wget -qO /tmp/earnapp_install.sh https://brightdata.com/static/earnapp/install.sh \
    || err "Failed to download EarnApp installer."

  info "Running EarnApp installer (sudo prompts visible)..."
  sudo bash /tmp/earnapp_install.sh

  ok "EarnApp installed."

  info "Checking EarnApp service status..."
  if systemctl is-active --quiet earnapp; then
    ok "EarnApp service is running."
  else
    warn "EarnApp service is not running. Attempting to start..."
    sudo systemctl start earnapp || err "Failed to start EarnApp service."
  fi

  info "Retrieving EarnApp pairing URL..."
  EARNAPP_PAIR_URL=$(sudo journalctl -u earnapp -n 200 | grep -o 'https://earnapp\.com[^ ]*' | tail -n 1 || true)

  if [[ -z "$EARNAPP_PAIR_URL" ]]; then
    warn "Could not automatically detect EarnApp pairing URL."
    echo "You can view it manually with:"
    echo "  sudo journalctl -u earnapp -f"
  else
    ok "EarnApp pairing URL captured."
  fi
}

install_earnapp_native

###############################################
# User Prompts for Docker Services
###############################################

read -rp "Install Honeygain in Docker? (Y/n): " INSTALL_HONEYGAIN
INSTALL_HONEYGAIN=${INSTALL_HONEYGAIN:-Y}

HONEYGAIN_EMAIL=""
HONEYGAIN_PASSWORD=""

if [[ "$INSTALL_HONEYGAIN" =~ ^[Yy]$ ]]; then
  read -rp "Enter your Honeygain email: " HONEYGAIN_EMAIL
  read -rsp "Enter your Honeygain password: " HONEYGAIN_PASSWORD
  echo
fi

###############################################
# Data Directories
###############################################

sudo mkdir -p \
  "$DATA_ROOT/honeygain" \
  "$DATA_ROOT/netdata" \
  "$DATA_ROOT/portainer" \
  "$DATA_ROOT/diun"

sudo chown -R "$REAL_USER":"$REAL_USER" "$DATA_ROOT" || true

ok "Data directories prepared."

###############################################
# Generate docker-compose.yml
###############################################

info "Generating docker-compose.yml..."
cat > "$COMPOSE_FILE" <<EOF
services:
EOF

# Honeygain
if [[ "$INSTALL_HONEYGAIN" =~ ^[Yy]$ && -n "$HONEYGAIN_EMAIL" && -n "$HONEYGAIN_PASSWORD" ]]; then
  ok "Honeygain will be installed in Docker."
  cat >> "$COMPOSE_FILE" <<EOF

  honeygain:
    image: honeygain/honeygain:latest
    container_name: honeygain
    restart: always
    command: -tou-accept -email $HONEYGAIN_EMAIL -pass $HONEYGAIN_PASSWORD -device earnbox
    volumes:
      - $DATA_ROOT/honeygain:/data
EOF
else
  warn "Honeygain installation skipped."
fi

# Core services
cat >> "$COMPOSE_FILE" <<EOF

  nginx:
    image: nginx:alpine
    container_name: nginx
    restart: always
    ports:
      - "80:80"
    volumes:
      - ./dashboard:/usr/share/nginx/html:ro

  netdata:
    image: netdata/netdata:stable
    container_name: netdata
    restart: always
    ports:
      - "19999:19999"
    cap_add:
      - SYS_PTRACE
    security_opt:
      - apparmor:unconfined
    volumes:
      - $DATA_ROOT/netdata:/var/lib/netdata

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - $DATA_ROOT/portainer:/data

  diun:
    image: crazymax/diun:latest
    container_name: diun
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - $DATA_ROOT/diun:/data
    environment:
      - TZ=America/Edmonton
      - LOG_LEVEL=info
      - DIUN_WATCH_WORKERS=20
      - DIUN_WATCH_SCHEDULE=0 */6 * * *
      - DIUN_PROVIDERS_DOCKER=true
EOF

ok "docker-compose.yml generated."

###############################################
# Deploy Docker Stack
###############################################

info "Pulling containers..."
docker compose -f "$COMPOSE_FILE" pull

info "Starting containers..."
docker compose -f "$COMPOSE_FILE" up -d

ok "Docker stack deployment complete."

###############################################
# Dashboard Local API Setup
###############################################

echo ">>> Setting up EarnBox Dashboard API..."

# Ensure local-api directory exists (should already be in repo, but self-heal if missing)
mkdir -p "$REPO_ROOT/local-api"

# Ensure api.sh is executable
if [ -f "$REPO_ROOT/local-api/api.sh" ]; then
  chmod +x "$REPO_ROOT/local-api/api.sh"
else
  warn "local-api/api.sh not found in repo. Dashboard API will not function until it is added."
fi

# Install systemd service if present
if [ -f "$REPO_ROOT/local-api/api.service" ]; then
  sudo cp "$REPO_ROOT/local-api/api.service" /etc/systemd/system/api.service
  sudo systemctl daemon-reload
  sudo systemctl enable api.service
  sudo systemctl restart api.service
  echo ">>> API service installed and running."
else
  warn "local-api/api.service not found in repo. API service not installed."
fi

###############################################
# Dependencies for API (SMART + vcgencmd)
###############################################

echo ">>> Installing required packages..."
sudo apt-get update -y
sudo apt-get install -y smartmontools

# Ensure vcgencmd exists (Raspberry Pi OS)
if ! command -v vcgencmd >/dev/null; then
  echo ">>> WARNING: vcgencmd not found. Installing raspberrypi-utils..."
  sudo apt-get install -y libraspberrypi-bin
fi

echo ">>> Dependencies installed."

###############################################
# Web Symlinks for Dashboard + API
###############################################

# Ensure dashboard is web-served
if [ ! -d /var/www/html/dashboard ]; then
  echo ">>> Linking dashboard to /var/www/html/dashboard..."
  sudo ln -s "$REPO_ROOT/dashboard" /var/www/html/dashboard
fi

# Ensure local-api is web-served
if [ ! -d /var/www/html/local-api ]; then
  echo ">>> Linking local-api to /var/www/html/local-api..."
  sudo ln -s "$REPO_ROOT/local-api" /var/www/html/local-api
fi

echo ">>> Dashboard and API are now web-accessible."

###############################################
# Final Output
###############################################

echo
ok "EarnBox installation complete."

echo
echo "Dashboard (nginx):  http://<your-pi-ip>/"
echo "Netdata:            http://<your-pi-ip>:19999/"
echo "Portainer:          http://<your-pi-ip>:9000/"

if [[ -n "$EARNAPP_PAIR_URL" ]]; then
  echo
  echo -e "${GREEN}EarnApp Pairing URL:${RESET}"
  echo "$EARNAPP_PAIR_URL"
  echo
  echo "Open this link in your browser to activate EarnApp on this device."
fi
