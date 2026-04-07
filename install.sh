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
# Docker Preflight + Auto‑Installer
###############################################

install_docker() {
  info "Installing Docker..."
  curl -fsSL https://get.docker.com | sudo sh || err "Docker installation failed."
  ok "Docker installed."
}

ensure_docker_group() {
  # If already in docker group, do nothing
  if groups "$USER" | grep -q '\bdocker\b'; then
    ok "User '$USER' is already in docker group."
    return
  fi

  info "Adding user '$USER' to docker group..."
  sudo usermod -aG docker "$USER"
  ok "User added to docker group."

  info "Re-running script inside docker group..."
  exec sg docker "$0"
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

# Run checks
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
# User Prompts
###############################################

read -rp "Install EarnApp? (Y/n): " INSTALL_EARNAPP
INSTALL_EARNAPP=${INSTALL_EARNAPP:-Y}

read -rp "Install Honeygain? (Y/n): " INSTALL_HONEYGAIN
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

mkdir -p \
  "$DATA_ROOT/earnapp" \
  "$DATA_ROOT/honeygain" \
  "$DATA_ROOT/netdata" \
  "$DATA_ROOT/portainer"

ok "Data directories created."

###############################################
# Generate docker-compose.yml
###############################################

cat > "$COMPOSE_FILE" <<EOF
services:
EOF

# EarnApp
if [[ "$INSTALL_EARNAPP" =~ ^[Yy]$ ]]; then
  ok "EarnApp will be installed."
  cat >> "$COMPOSE_FILE" <<EOF

  earnapp:
    image: fazalfarhan01/earnapp:latest
    container_name: earnapp
    restart: always
    volumes:
      - $DATA_ROOT/earnapp:/etc/earnapp
EOF
else
  warn "EarnApp installation skipped."
fi

# Honeygain
if [[ "$INSTALL_HONEYGAIN" =~ ^[Yy]$ && -n "$HONEYGAIN_EMAIL" && -n "$HONEYGAIN_PASSWORD" ]]; then
  ok "Honeygain will be installed."
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

  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: always
    command: --cleanup --schedule "0 0 * * *"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
EOF

ok "docker-compose.yml generated."

###############################################
# Deploy Stack
###############################################

info "Pulling containers..."
docker compose -f "$COMPOSE_FILE" pull

info "Starting containers..."
docker compose -f "$COMPOSE_FILE" up -d

ok "Deployment complete."
echo
ok "Your EarnBox stack is now running."
echo "Dashboard: http://<your-pi-ip>"
echo "Netdata:   http://<your-pi-ip>:19999"
echo "Portainer: http://<your-pi-ip>:9000"
