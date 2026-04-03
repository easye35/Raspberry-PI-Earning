#!/usr/bin/env bash
# Appliance-grade installer orchestrator for this repo

set -Eeuo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND"' ERR

if [[ $EUID -ne 0 ]]; then
    echo "Installer is not running as root — elevating..."
    exec sudo -E bash "$0" "$@"
fi
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${ROOT_DIR}/lib"
MODULE_DIR="${ROOT_DIR}/modules"

# Export library paths for all modules
export LOG_LIB="${LIB_DIR}/logging.sh"
export SYS_LIB="${LIB_DIR}/system.sh"
export DOCKER_LIB="${LIB_DIR}/docker.sh"
