#!/usr/bin/env bash
# Usage: rm-dsstore.sh [options] [directory]
#   -r, --recursive   Search subdirectories (default: current dir only)
#   -d, --dry-run     Preview files without deleting
#   -h, --help        Show this help

set -euo pipefail

GREEN="\033[32m"; YELLOW="\033[33m"; BOLD="\033[1m"; RESET="\033[0m"

success() { printf "${GREEN}✅ %s${RESET}\n" "$*"; }
warn()    { printf "${YELLOW}⚠️  %s${RESET}\n" "$*"; }
info()    { printf "${BOLD}💡 %s${RESET}\n" "$*"; }

usage() {
    printf "Usage: %s [-r] [-d] [directory]\n" "$(basename "$0")"
    printf "  -r, --recursive   Search subdirectories\n"
    printf "  -d, --dry-run     Preview without deleting\n"
    printf "  -h, --help        Show this help\n"
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

RECURSIVE=false
DRY_RUN=false
TARGET="."

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--recursive) RECURSIVE=true ;;
        -d|--dry-run)   DRY_RUN=true ;;
        -h|--help)      usage ;;
        -*) warn "Unknown option: $1"; usage ;;
        *)  TARGET="$1" ;;
    esac
    shift
done

if $RECURSIVE; then
    mapfile -t files < <(find "$TARGET" -name ".DS_Store" -type f)
else
    mapfile -t files < <(find "$TARGET" -maxdepth 1 -name ".DS_Store" -type f)
fi

if [[ ${#files[@]} -eq 0 ]]; then
    success "No .DS_Store files found in ${TARGET}"
    exit 0
fi

info "Found ${#files[@]} .DS_Store file(s) in ${TARGET}:"
for f in "${files[@]}"; do
    printf "  %s\n" "$f"
done

if $DRY_RUN; then
    warn "Dry run — no files deleted."
    exit 0
fi

if confirm "Delete ${#files[@]} .DS_Store file(s)?"; then
    for f in "${files[@]}"; do
        rm -f "$f"
    done
    success "Removed ${#files[@]} .DS_Store file(s)."
else
    warn "Aborted — no files deleted."
fi
