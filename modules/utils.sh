#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# Logging Library Loader
###############################################################################

# Determine absolute path to this directory
UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to logging library
LOG_LIB="$UTILS_DIR/logging.sh"
export LOG_LIB

# Load logging functions
if [[ -f "$LOG_LIB" ]]; then
    source "$LOG_LIB"
else
    echo "[ERROR] Logging library not found at: $LOG_LIB"
    exit 1
fi

###############################################################################
# Shared Utility Functions
###############################################################################

# Example shared function (extend as needed)
utils::require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log::fail "This installer must be run as root."
        exit 1
    fi
}

utils::file_exists() {
    local f="$1"
    [[ -f "$f" ]]
}

utils::dir_exists() {
    local d="$1"
    [[ -d "$d" ]]
}

utils::pause() {
    read -rp "Press Enter to continue..."
}

###############################################################################
# End of utils.sh
###############################################################################
