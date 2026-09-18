#!/usr/bin/env bash
# Removes Ghostty installed by install-ghostty.sh. Leaves ~/.config/ghostty/config
# (symlinked by sys-symlinks.sh) untouched — same convention as remove-python.sh not
# wiping venvs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

echo "--------------------------------"
cog_msg "Removing Ghostty..."
echo "--------------------------------"

if ! command -v ghostty &>/dev/null; then
    warn "Not installed: ghostty"
    exit 0
fi

if [[ "$OS" == "macos" ]]; then
    brew uninstall --cask ghostty || true

elif [[ "$OS" == "debian" ]]; then
    sudo apt remove -y ghostty
    sudo apt autoremove -y

else
    error "Unsupported OS: ${OS}"; exit 1
fi

success "Ghostty removed."
