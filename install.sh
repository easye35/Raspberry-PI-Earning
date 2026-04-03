#!/usr/bin/env bash
set -e

DATA_ROOT="/mnt/storage"
REPO_ROOT="$HOME/Raspberry-PI-docker-Earning"
COMPOSE_FILE="$REPO_ROOT/docker-compose.yml"

echo "[INFO] Using data root: $DATA_ROOT"

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

mkdir -p "$DATA_ROOT/earnapp" "$DATA_ROOT/honeygain" \
         "$DATA_ROOT/netdata" "$DATA_ROOT/portainer"

cat > "$COMPOSE_FILE" <<EOF
services:
EOF

if [[ "$INSTALL_EARNAPP" =~ ^[Yy]$ ]]; then
  echo "[OK] EarnApp will be installed."
  cat >> "$COMPOSE_FILE" <<'EOF'

  earnapp:
    image: fazalfarhan01/earnapp:latest
    container_name: earnapp
    restart: always
    volumes:
      - /mnt/storage/earnapp:/etc/earnapp
EOF
else
  echo "[WARN] EarnApp installation skipped."
fi

if [[ "$INSTALL_HONEYGAIN" =~ ^[Yy]$ && -n "$HONEYGAIN_EMAIL" && -n "$HONEYGAIN_PASSWORD" ]]; then
  echo "[OK] Honeygain will be installed."
  cat >> "$COMPOSE_FILE" <<EOF

  honeygain:
    image: honeygain/honeygain:latest
    container_name: honeygain
    restart: always
    command: -tou-accept -email $HONEYGAIN_EMAIL -pass $HONEYGAIN_PASSWORD -device earnbox
    volumes:
      - /mnt/storage/honeygain:/data
EOF
else
  echo "[WARN] Honeygain installation skipped."
fi

cat >> "$COMPOSE_FILE" <<'EOF'

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
      - /mnt/storage/netdata:/var/lib/netdata

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /mnt/storage/portainer:/data

  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: always
    command: --cleanup --schedule "0 0 * * *"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
EOF

echo "==> Pulling and starting containers via docker compose"
cd "$REPO_ROOT"
docker compose pull
docker compose up -d
echo "[OK] Deployment complete."
