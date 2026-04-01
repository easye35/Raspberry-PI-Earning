#!/usr/bin/env bash
# Ultra-modern color + symbol library
# Provides 256-color, RGB fallback, and styled prefixes.

# Detect terminal color support
if tput colors &>/dev/null; then
    COLOR_SUPPORT=$(tput colors)
else
    COLOR_SUPPORT=0
fi

# 256-color helpers
color_256() {
    local code="$1"
    printf "\e[38;5;${code}m"
}

bg_256() {
    local code="$1"
    printf "\e[48;5;${code}m"
}

# RGB helpers (fallback if 256 unavailable)
color_rgb() {
    local r="$1" g="$2" b="$3"
    printf "\e[38;2;${r};${g};${b}m"
}

bg_rgb() {
    local r="$1" g="$2" b="$3"
    printf "\e[48;2;${r};${g};${b}m"
}

# Reset
RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"
UNDERLINE="\e[4m"

# Symbols (UTF-8 safe)
SYMBOL_OK="[OK]"
SYMBOL_FAIL="[X]"
SYMBOL_WARN="[!]"
SYMBOL_INFO="->""

# High-level color presets (auto-select best available)
if [[ "$COLOR_SUPPORT" -ge 256 ]]; then
    COLOR_OK=$(color_256 82)        # green
    COLOR_FAIL=$(color_256 196)     # red
    COLOR_WARN=$(color_256 214)     # orange
    COLOR_INFO=$(color_256 39)      # blue
    COLOR_TITLE=$(color_256 141)    # purple
else
    COLOR_OK="\e[32m"
    COLOR_FAIL="\e[31m"
    COLOR_WARN="\e[33m"
    COLOR_INFO="\e[34m"
    COLOR_TITLE="\e[35m"
fi

# Styled prefixes for logging
PREFIX_OK="${COLOR_OK}${SYMBOL_OK}${RESET}"
PREFIX_FAIL="${COLOR_FAIL}${SYMBOL_FAIL}${RESET}"
PREFIX_WARN="${COLOR_WARN}${SYMBOL_WARN}${RESET}"
PREFIX_INFO="${COLOR_INFO}${SYMBOL_INFO}${RESET}"
