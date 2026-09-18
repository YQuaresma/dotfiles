#!/usr/bin/env bash
# Removes omp installed by install-omp.sh. Leaves ~/.omp (agent config, models.yml,
# API keys, cache) untouched — same convention as remove-python.sh not wiping venvs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

echo "--------------------------------"
cog_msg "Removing omp (Oh My Pi)..."
echo "--------------------------------"

if ! command -v omp &>/dev/null; then
    warn "Not installed: omp"
    exit 0
fi

if [[ "$OS" == "macos" ]]; then
    brew uninstall can1357/tap/omp || true
    brew untap can1357/tap || true

elif [[ "$OS" == "debian" ]]; then
    rm -f "$HOME/.local/bin/omp"

else
    error "Unsupported OS: ${OS}"; exit 1
fi

success "omp removed."
