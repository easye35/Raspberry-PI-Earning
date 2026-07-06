#!/bin/bash

# Repocket Setup Plugin
# Note: Repocket now runs as a Docker service in docker-compose.yml
# This plugin is kept for reference/future extensions

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_DIR/.env"

# Load .env if it exists
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

if [ -z "$RP_EMAIL" ] || [ -z "$RP_API_KEY" ]; then
    echo "⚠️  RP_EMAIL or RP_API_KEY not found in .env. Repocket service will not start."
    exit 0
fi

echo "✅ Repocket credentials configured in .env"
echo "ℹ️  Repocket will run as a Docker service when you start docker-compose"
