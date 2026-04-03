#!/usr/bin/env bash
# Main installer for Raspberry-PI-docker-Earning

set -Eeuo pipefail

###############################################################################
# 1. Ensure Bash is installed BEFORE running any modules
###############################################################################
if ! command -v bash >/dev/null 2>&1; then
    echo "[INFO] Bash not found — installing it now..."
    apt update && apt install -y bash
    echo "[INFO] Bash installed successfully."
fi

###############################################################################
# 2. Load utilities (must be SOURCED, not executed)
###############################################################################
UTILS="modules/utils.sh"

if [[ ! -f "$UTILS" ]]; then
    echo "[ERROR] Missing $UTILS"
    exit 1
fi

# Correct: load logging + helpers into THIS shell
source "$UTILS"

###############################################################################
# 3. Module list
###############################################################################
MODULES=(
    "10-stop-and-clean.sh"
    "20-power-check.sh"
    "30-detect-storage.sh"
    "35-mount-and-prepare-storage.sh"
    "40-migrate-storage.sh"
    "45-migrate-docker.sh"
    "50-verify-storage.sh"
)

###############################################################################
# 4. Run each module using Bash
###############################################################################
for module in "${MODULES[@]}"; do
    path="modules/$module"

    if [[ ! -f "$path" ]]; then
        echo "[ERROR] Missing module: $path"
        exit 1
    fi

    echo "Running module: $module"
    echo "▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒"

    # Run module with Bash (now guaranteed to exist)
    if ! bash "$path"; then
        echo "❌ ERROR running module: $module"
        exit 1
    fi
done

###############################################################################
# 5. Final message
###############################################################################
echo "=== Resync complete: $(date) ==="
