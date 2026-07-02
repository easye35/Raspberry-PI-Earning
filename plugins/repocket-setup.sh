#!/bin/bash

# Repocket Setup Plugin
# Configures Repocket token from .env

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

echo "🎯 Configuring Repocket token..."

# Create config directory
CONFIG_DIR="$HOME/.repocket"
mkdir -p "$CONFIG_DIR"

# Write token to config
cat > "$CONFIG_DIR/config" <<EOF
token=$REPOCKET_TOKEN
EOF

chmod 600 "$CONFIG_DIR/config"

echo "✅ Repocket token configured at $CONFIG_DIR/config"

# Check if Repocket is installed
if command -v repocket &> /dev/null; then
    echo "✅ Repocket is installed"
    
    # Optionally restart if it's running as a systemd service
    if systemctl is-active --quiet repocket 2>/dev/null; then
        echo "🔄 Restarting Repocket service..."
        sudo systemctl restart repocket || echo "⚠️  Could not restart Repocket service"
    fi
else
    echo "ℹ️  Repocket is not installed yet."
    echo "   Install Repocket using one of these methods:"
    echo "   - npm: npm install -g repocket"
    echo "   - Download from: https://repocket.co/"
    echo "   - Or check Repocket's documentation for installation instructions"
fi

echo "✅ Repocket setup complete"
