#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# Color Definitions
###############################################################################

COLOR_RESET="\033[0m"
COLOR_INFO="\033[1;34m"
COLOR_WARN="\033[1;33m"
COLOR_ERROR="\033[1;31m"
COLOR_OK="\033[1;32m"
COLOR_STEP="\033[1;36m"
COLOR_SUBSTEP="\033[0;36m"
COLOR_DEBUG="\033[0;90m"

###############################################################################
# Logging Functions
###############################################################################

log::info() {
    echo -e "${COLOR_INFO}[INFO]${COLOR_RESET} $*"
}

log::warn() {
    echo -e "${COLOR_WARN}[WARN]${COLOR_RESET} $*"
}

log::error() {
    echo -e "${COLOR_ERROR}[ERROR]${COLOR_RESET} $*"
}

log::ok() {
    echo -e "${COLOR_OK}[OK]${COLOR_RESET} $*"
}

log::step() {
    echo -e "${COLOR_STEP}==>${COLOR_RESET} $*"
}

log::substep() {
    echo -e "${COLOR_SUBSTEP}  ->${COLOR_RESET} $*"
}

log::debug() {
    echo -e "${COLOR_DEBUG}[DEBUG]${COLOR_RESET} $*"
}

log::fail() {
    echo -e "${COLOR_ERROR}[FAIL]${COLOR_RESET} $*"
    exit 1
}

log::die() {
    echo -e "${COLOR_ERROR}[FATAL]${COLOR_RESET} $*"
    exit 1
}

log::success_block() {
    echo -e "${COLOR_OK}"
    echo "========================================"
    echo "  $*"
    echo "========================================"
    echo -e "${COLOR_RESET}"
}

###############################################################################
# End of logging.sh
###############################################################################
