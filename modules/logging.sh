#!/usr/bin/env bash
set -euo pipefail

# ____________________________________________
# Logging Normalization Script
# Converts all modules to use:
#   log::section / log::info / log::warn / log::error / log::success
# ____________________________________________

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

modules_dir="modules"

echo -e "${BLUE}🔧 Normalizing logging syntax in modules/...${NC}"

# Patterns to replace → canonical log functions
declare -A REPLACEMENTS=(
    # echo variants
    ["echo -e \"\\\[0;31m"]="log::error"
    ["echo -e \"\\\[0;32m"]="log::info"
    ["echo -e \"\\\[1;33m"]="log::warn"
    ["echo -e \"\\\[0;34m"]="log::section"
    ["echo -e"]="log::info"
    ["echo "]="log::info "

    # printf variants
    ["printf \"\\\[0;31m"]="log::error"
    ["printf \"\\\[0;32m"]="log::info"
    ["printf \"\\\[1;33m"]="log::warn"
    ["printf \"\\\[0;34m"]="log::section"
    ["printf "]="log::info "

    # legacy prefixes
    ["INFO:"]="log::info"
    ["WARN:"]="log::warn"
    ["ERROR:"]="log::error"
    ["SECTION:"]="log::section"

    # underscore-style legacy calls (function-call aware)
    ["log_section "]="log::section "
    ["log_info "]="log::info "
    ["log_warn "]="log::warn "
    ["log_success "]="log::success "

    # indented variants
    ["    log_section "]="    log::section "
    ["    log_info "]="    log::info "
    ["    log_warn "]="    log::warn "
    ["    log_success "]="    log::success "

    # double-indent variants
    ["        log_section "]="        log::section "
    ["        log_info "]="        log::info "
    ["        log_warn "]="        log::warn "
    ["        log_success "]="        log::success "
)

# Track changes
changed_files=0
scanned_files=0

# ____________________________________________
# Normalize a single file
# ____________________________________________
normalize_file() {
    local file="$1"
    local tmp="$(mktemp)"

    cp "$file" "$tmp"

    for pattern in "${!REPLACEMENTS[@]}"; do
        replacement="${REPLACEMENTS[$pattern]}"
        sed -i "s|$pattern|$replacement|g" "$tmp"
    done

    if ! diff -q "$file" "$tmp" >/dev/null 2>&1; then
        cp "$tmp" "$file"
        echo -e "  ${GREEN}✔ Updated:${NC} $file"
        ((changed_files++))
    else
        echo -e "  ${YELLOW}• No changes:${NC} $file"
    fi

    rm "$tmp"
    ((scanned_files++))
}

# ____________________________________________
# Walk modules directory
# ____________________________________________
if [[ ! -d "$modules_dir" ]]; then
    echo -e "${RED}❌ modules/ directory not found${NC}"
    exit 1
fi

while IFS= read -r -d '' file; do
    normalize_file "$file"
done < <(find "$modules_dir" -type f \( -name "*.sh" -o -name "*.bash" -o -name "*.inc" \) -print0)

# ____________________________________________
# Summary
# ____________________________________________
echo -e "\n${BLUE}📊 Logging Normalization Summary${NC}"
echo -e "  ${BLUE}Files scanned:${NC}  $scanned_files"
echo -e "  ${GREEN}Files updated:${NC} $changed_files"

if (( changed_files > 0 )); then
    echo -e "\n${GREEN}✨ Logging syntax successfully normalized.${NC}"
else
    echo -e "\n${YELLOW}No changes were required.${NC}"
fi
