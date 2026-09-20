#!/usr/bin/env bash
# Locates GitKraken's per-profile "profile" JSON file(s) (under
# ~/.gitkraken/profiles/<hash>/profile on Linux, or GitKraken's equivalent
# macOS support dir) and clears the "userEmail" and "userName" fields so the
# app falls through to git's resolved user.name/user.email instead of a
# stale/wrong override.
#
# Usage: sys-gitkraken-clear-identity.sh [-d|--dry-run] [-h|--help]
set -euo pipefail

GREEN="\033[32m"; YELLOW="\033[33m"; BOLD="\033[1m"; RESET="\033[0m"

success() { printf "${GREEN}✅ %s${RESET}\n" "$*"; }
warn()    { printf "${YELLOW}⚠️  %s${RESET}\n" "$*"; }
info()    { printf "${BOLD}💡 %s${RESET}\n" "$*"; }

usage() {
    printf "Usage: %s [-d|--dry-run] [-h|--help]\n" "$(basename "$0")"
    printf "  -d, --dry-run   Show what would change, don't write anything\n"
    printf "  -h, --help      Show this help\n"
    exit 0
}

confirm() {
    while true; do
        read -r -p "▶️  $1 [y/N]: " response
        case "$response" in
            [yY]*) return 0 ;;
            [nN]|"") return 1 ;;
            *) warn "Please answer Y or N" ;;
        esac
    done
}

DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dry-run) DRY_RUN=true ;;
        -h|--help)    usage ;;
        *) warn "Unknown option: $1"; usage ;;
    esac
    shift
done

if ! command -v jq >/dev/null 2>&1; then
    warn "jq is required but not installed. Install it and re-run."
    exit 1
fi

# GitKraken's config root: ~/.gitkraken on Linux, and the same layout under
# macOS's Application Support dir. Both are checked; missing ones are skipped.
search_dirs=(
    "$HOME/.gitkraken/profiles"
    "$HOME/Library/Application Support/GitKraken/profiles"
)

profiles=()
for dir in "${search_dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' f; do
        profiles+=("$f")
    done < <(find "$dir" -mindepth 2 -maxdepth 2 -type f -name "profile" -print0)
done

if [[ ${#profiles[@]} -eq 0 ]]; then
    warn "No GitKraken profile files found under: ${search_dirs[*]}"
    exit 0
fi

info "Found ${#profiles[@]} GitKraken profile file(s):"
changed=0
for f in "${profiles[@]}"; do
    email="$(jq -r '.userEmail // ""' "$f")"
    name="$(jq -r '.userName // ""' "$f")"
    printf "  %s (userEmail=%s, userName=%s)\n" "$f" "${email:-<empty>}" "${name:-<empty>}"

    if [[ -z "$email" && -z "$name" ]]; then
        success "  already clear, skipping"
        continue
    fi

    if $DRY_RUN; then
        warn "  dry run — would clear userEmail/userName"
        continue
    fi

    if confirm "Clear userEmail/userName in $(basename "$(dirname "$f")")/profile?"; then
        cp "$f" "${f}.bak"
        jq '.userEmail = "" | .userName = ""' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
        success "  cleared (backup: ${f}.bak)"
        changed=$((changed + 1))
    else
        warn "  skipped"
    fi
done

echo
if [[ $changed -gt 0 ]]; then
    warn "Quit GitKraken fully before it overwrites this file, then relaunch to pick up the change."
    success "Cleared userEmail/userName in ${changed} profile file(s)."
else
    info "No changes made."
fi
