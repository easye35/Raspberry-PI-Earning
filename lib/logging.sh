#!/usr/bin/env bash
# Appliance-grade logging library
# Requires: lib/colors.sh

# Resolve library directory
LIB_DIR="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=colors.sh
source "${LIB_DIR}/colors.sh"

# Timestamp toggle (default: off)
LOG_SHOW_TIMESTAMP=false

log::timestamp() {
    $LOG_SHOW_TIMESTAMP && date +"[%Y-%m-%d %H:%M:%S] " || true
}

log::raw() {
    local msg="$1"
    printf "%b%s%b\n" "$(log::timestamp)" "$msg" "$RESET"
}

log::info() {
    log::raw "${PREFIX_INFO} ${COLOR_INFO}$1${RESET}"
}

log::ok() {
    log::raw "${PREFIX_OK} ${COLOR_OK}$1${RESET}"
}

log::warn() {
    log::raw "${PREFIX_WARN} ${COLOR_WARN}$1${RESET}"
}

log::fail() {
    log::raw "${PREFIX_FAIL} ${COLOR_FAIL}$1${RESET}"
}

log::title() {
    printf "\n%b%s%b\n" "${COLOR_TITLE}${BOLD}" "$1" "${RESET}"
}

log::section() {
    local title="$1"
    local line
    line=$(printf "%*s" "$(tput cols 2>/dev/null || echo 60)" "" | tr ' ' '─')

    printf "\n%b%s%b\n" "${COLOR_TITLE}${BOLD}" "$line" "${RESET}"
    printf "%b%s%b\n" "${COLOR_TITLE}${BOLD}" "  $title" "${RESET}"
    printf "%b%s%b\n\n" "${COLOR_TITLE}${BOLD}" "$line" "${RESET}"
}

log::die() {
    log::fail "$1"
    exit 1
}

log::indent() {
    local prefix="    "
    while IFS= read -r line; do
        printf "%s%s\n" "$prefix" "$line"
    done
}
