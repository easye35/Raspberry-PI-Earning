#!/bin/bash

# Repocket Setup Plugin
# Configures Repocket with token from .env

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_DIR/.env"

# Load .env if it exists
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

if [ -z "$REPOCKET_TOKEN" ]; then
    echo "⚠️  REPOCKET_TOKEN not found in .env. Skipping Repocket setup."
    exit 0
fi

echo "🎯 Setting up Repocket..."

# Check if Repocket is installed
if ! command -v repocket &> /dev/null; then
    echo "📦 Repocket not found. Installing..."
    if command -v curl &> /dev/null; then
        bash <(curl -s https://get.repocket.co/install.sh)
    elif command -v wget &> /dev/null; then
        bash <(wget -qO- https://get.repocket.co/install.sh)
    else
        echo "❌ Neither curl nor wget available. Please install Repocket manually."
        exit 1
    fi
fi

# Create config directory if needed
CONFIG_DIR="$HOME/.repocket"
mkdir -p "$CONFIG_DIR"

# Write token to config (exact format depends on Repocket's config file)
# This is a common pattern - adjust if Repocket uses a different format
cat > "$CONFIG_DIR/config" <<EOF
token=$REPOCKET_TOKEN
EOF

chmod 600 "$CONFIG_DIR/config"

echo "✅ Repocket configured with token"

# Optionally restart Repocket if it's running as a systemd service
if systemctl is-active --quiet repocket; then
    echo "🔄 Restarting Repocket service..."
    sudo systemctl restart repocket
fi

echo "✅ Repocket setup complete"
