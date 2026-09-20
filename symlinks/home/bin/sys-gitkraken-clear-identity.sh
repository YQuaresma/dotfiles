#!/usr/bin/env bash
# Clears GitKraken's stale/wrong cached email in two places:
#   - the per-profile "profile" JSON file(s) (~/.gitkraken/profiles/<hash>/profile
#     on Linux, or GitKraken's equivalent macOS support dir) — the "userEmail" field
#   - the top-level "config" JSON (~/.gitkraken/config, or the macOS equivalent) —
#     the "registration.email" field (the account login email)
# Clearing either makes GitKraken fall through to git's resolved user.email
# instead of the stale override.
#
# "userName"/"registration.name" are left untouched: GitKraken falls back to
# the account registration name (not git config) when userName is blank, so
# clearing it only replaces one wrong value with another.
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

changed=0

# clear_email FILE JQ_GET_EXPR JQ_SET_EXPR LABEL
clear_email() {
    local f="$1" get="$2" set="$3" label="$4"
    local email
    email="$(jq -r "$get // \"\"" "$f")"
    printf "  %s (%s=%s)\n" "$f" "$label" "${email:-<empty>}"

    if [[ -z "$email" ]]; then
        success "  already clear, skipping"
        return
    fi

    if $DRY_RUN; then
        warn "  dry run — would clear $label"
        return
    fi

    if confirm "Clear $label in $f?"; then
        cp "$f" "${f}.bak"
        jq "$set" "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
        success "  cleared (backup: ${f}.bak)"
        changed=$((changed + 1))
    else
        warn "  skipped"
    fi
}

# GitKraken's config root: ~/.gitkraken on Linux, and the same layout under
# macOS's Application Support dir. Both are checked; missing ones are skipped.
profile_dirs=(
    "$HOME/.gitkraken/profiles"
    "$HOME/Library/Application Support/GitKraken/profiles"
)
config_files=(
    "$HOME/.gitkraken/config"
    "$HOME/Library/Application Support/GitKraken/config"
)

profiles=()
for dir in "${profile_dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' f; do
        profiles+=("$f")
    done < <(find "$dir" -mindepth 2 -maxdepth 2 -type f -name "profile" -print0)
done

configs=()
for f in "${config_files[@]}"; do
    [[ -f "$f" ]] && configs+=("$f")
done

if [[ ${#profiles[@]} -eq 0 && ${#configs[@]} -eq 0 ]]; then
    warn "No GitKraken profile or config files found."
    exit 0
fi

if [[ ${#profiles[@]} -gt 0 ]]; then
    info "Found ${#profiles[@]} GitKraken profile file(s):"
    for f in "${profiles[@]}"; do
        clear_email "$f" '.userEmail' '.userEmail = ""' "userEmail"
    done
fi

if [[ ${#configs[@]} -gt 0 ]]; then
    info "Found ${#configs[@]} GitKraken config file(s):"
    for f in "${configs[@]}"; do
        clear_email "$f" '.registration.email' '.registration.email = ""' "registration.email"
    done
fi

echo
if [[ $changed -gt 0 ]]; then
    warn "Quit GitKraken fully before it overwrites these files, then relaunch to pick up the change."
    success "Cleared email in ${changed} file(s)."
else
    info "No changes made."
fi
