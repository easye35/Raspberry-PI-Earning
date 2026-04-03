#!/usr/bin/env bash
# Appliance-grade logging library (enhanced)
# Requires: lib/colors.sh

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=colors.sh
source "${LIB_DIR}/colors.sh"

LOG_SHOW_TIMESTAMP=false
LOG_DEBUG=false
LOG_STEP_COUNTER=0

log::timestamp() {
    $LOG_SHOW_TIMESTAMP && date +"[%Y-%m-%d %H:%M:%S] " || true
}

log::raw() {
    local msg="$1"
    printf "%b%s%b\n" "$(log::timestamp)" "$msg" "$RESET"
}

log::info()  { log::raw "${PREFIX_INFO} ${COLOR_INFO}$1${RESET}"; }
log::ok()    { log::raw "${PREFIX_OK} ${COLOR_OK}$1${RESET}"; }
log::warn()  { log::raw "${PREFIX_WARN} ${COLOR_WARN}$1${RESET}"; }
log::fail()  { log::raw "${PREFIX_FAIL} ${COLOR_FAIL}$1${RESET}"; }

log::debug() {
    $LOG_DEBUG && log::raw "${PREFIX_INFO} ${COLOR_DIM}[debug] $1${RESET}"
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

log::hr() {
    local line
    line=$(printf "%*s" "$(tput cols 2>/dev/null || echo 60)" "" | tr ' ' '─')
    printf "%b%s%b\n" "${COLOR_DIM}" "$line" "${RESET}"
}

log::step() {
    ((LOG_STEP_COUNTER++))
    log::raw "${COLOR_TITLE}${BOLD}[Step ${LOG_STEP_COUNTER}]${RESET} $1"
}

log::substep() {
    log::raw "    ${COLOR_DIM}→${RESET} $1"
}

log::box() {
    local msg="$1"
    local width=${#msg}
    local border
    border=$(printf "%*s" "$((width + 4))" "" | tr ' ' '─')

    printf "\n${COLOR_TITLE}${BOLD}%s${RESET}\n" "$border"
    printf "${COLOR_TITLE}${BOLD}│${RESET} $msg ${COLOR_TITLE}${BOLD}│${RESET}\n"
    printf "${COLOR_TITLE}${BOLD}%s${RESET}\n\n" "$border"
}

log::success_block() {
    local msg="$1"
    log::box "${COLOR_OK}${msg}${RESET}"
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

log_section() {
    echo -e "\n\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[1;36m$1\033[0m"
    echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
}

# Animated spinner for long operations
log::spinner() {
    local msg="$1"
    shift
    local cmd=("$@")

    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    printf "%s" "${COLOR_INFO}${msg}...${RESET}"

    (
        "${cmd[@]}"
    ) &
    local pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r%s %s" "${COLOR_INFO}${msg}${RESET}" "${spin:i++%${#spin}:1}"
        sleep 0.1
    done

    wait "$pid"
    local status=$?

    if [[ $status -eq 0 ]]; then
        printf "\r${PREFIX_OK} ${COLOR_OK}%s${RESET}\n" "$msg"
    else
        printf "\r${PREFIX_FAIL} ${COLOR_FAIL}%s (failed)${RESET}\n" "$msg"
    fi

    return $status
}
