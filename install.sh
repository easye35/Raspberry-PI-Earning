#!/usr/bin/env bash
set -e

echo "=============================================="
echo "     Raspberry-PI-docker-Earning Installer"
echo "=============================================="
echo ""

# --- Detect architecture -----------------------------------------------------

ARCH=$(uname -m)

echo "Detected architecture: $ARCH"

if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    echo ""
    echo "⚠ EarnApp's official Docker image does NOT support ARM64."
    echo "  If you continue with Docker mode, the container will fail to pull."
    echo ""
    echo "You can:"
    echo "  1) Install EarnApp natively on ARM (recommended)"
    echo "  2) Abort"
    echo ""

    read -p "Choose option (1 or 2): " ARM_CHOICE

    if [[ "$ARM_CHOICE" == "1" ]]; then
        echo ""
        echo "Installing EarnApp natively for ARM64..."
        curl -s https://earnapp.com/install.sh | bash
        echo ""
        echo "✔ Native EarnApp installation complete."
        exit 0
    else
        echo "Aborted by user."
        exit 1
    fi
fi

# --- Ask for EarnApp link ----------------------------------------------------

echo ""
read -p "Paste your EarnApp registration link: " EARNAPP_LINK

if [[ -z "$EARNAPP_LINK" ]]; then
    echo "❌ No link provided. Cannot continue."
    exit 1
fi

# --- Extract token -----------------------------------------------------------

TOKEN=""

# Case 1: URL ends with token
if [[ "$EARNAPP_LINK" =~ /([A-Za-z0-9]+)$ ]]; then
    TOKEN="${BASH_REMATCH[1]}"
fi

# Case 2: URL contains ?token=
if [[ "$EARNAPP_LINK" =~ token=([A-Za-z0-9]+) ]]; then
    TOKEN="${BASH_REMATCH[1]}"
fi

if [[ -z "$TOKEN" ]]; then
    echo "❌ Could not extract token from the link."
    echo "Make sure the link looks like:"
    echo "  https://earnapp.com/r/abcdef123456"
    echo "or:"
    echo "  https://earnapp.com/dashboard?token=abcdef123456"
    exit 1
fi

# --- Validate token ----------------------------------------------------------

if [[ ${#TOKEN} -lt 10 ]]; then
    echo "❌ Extracted token looks too short: $TOKEN"
    exit 1
fi

echo ""
echo "✔ Token extracted: $TOKEN"

# --- Write .env --------------------------------------------------------------

echo "EARNAPP_TOKEN=\"$TOKEN\"" > .env

echo "✔ .env updated."

# --- Show registration link --------------------------------------------------

echo ""
echo "👉 Follow this link to register your device:"
echo "$EARNAPP_LINK"
echo ""

# --- Deploy Docker container -------------------------------------------------

echo "Deploying EarnApp Docker container..."

docker rm -f earnapp >/dev/null 2>&1 || true

docker run -d \
    --name earnapp \
    --restart unless-stopped \
    -e EARNAPP_TOKEN="$TOKEN" \
    -v earnapp-data:/data \
    --pull always \
    fscarmen/earnapp

echo ""
echo "✔ EarnApp container deployed (if architecture supports it)."
echo "Check Portainer to confirm."
echo ""
echo "Done."
