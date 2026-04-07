#!/usr/bin/env bash
set -e

###############################################
#  EarnBox Appliance‑Grade Installer
#  Self‑locating, sudo‑safe, zero‑touch
###############################################

# --- Color Output ---
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; BLUE="\e[34m"; RESET="\e[0m"

info()  { echo -e "${BLUE}[INFO]${RESET} $1"; }
ok()    { echo -e "${GREEN}[OK]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $1"; }
err()   { echo -e "${RED}[ERROR]${RESET} $1"; exit 1; }

# --- Self‑locating repo root ---
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
REPO_ROOT="$SCRIPT_DIR"
COMPOSE_FILE="$REPO_ROOT/docker-compose.yml"

# --- Data root ---
DATA_ROOT="/mnt/storage"

info "Repo root: $REPO_ROOT"
info "Data root: $DATA_ROOT"

# --- Validate Docker ---
if ! command -v docker >/dev/null 2>&1; then
  err "Docker is not installed. Install Docker first."
fi

if ! docker compose version >/dev/null 2>&1; then
  err "Docker Compose v2 is not installed."
fi

# --- User prompts ---
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

# --- Create data directories ---
mkdir -p \
  "$DATA_ROOT/earnapp" \
  "$DATA_ROOT/honeygain" \
  "$DATA_ROOT/netdata" \
  "$DATA_ROOT/portainer"

ok "Data directories created."

# --- Begin writing docker-compose.yml ---
cat > "$COMPOSE_FILE" <<EOF
services:
EOF

###############################################
# EarnApp
###############################################
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

###############################################
# Honeygain
###############################################
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

###############################################
# Core Services (Dashboard, Netdata, Portainer, Watchtower)
###############################################
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
# Deploy
###############################################
info "Pulling containers..."
docker compose -f "$COMPOSE_FILE" pull

info "Starting containers..."
docker compose -f "$COMPOSE_FILE" up -d

ok "Deployment complete."
echo
ok "Your EarnBox appliance is now running."
echo "Dashboard: http://<your-pi-ip>"
echo "Netdata:   http://<your-pi-ip>:19999"
echo "Portainer: http://<your-pi-ip>:9000"
