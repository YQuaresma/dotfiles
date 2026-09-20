#!/usr/bin/env bash
# Removes Helium Browser installed by install-helium.sh — ad-hoc only, not run
# by setup.sh (same convention as remove-ghostty.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

echo "--------------------------------"
cog_msg "Removing Helium Browser..."
echo "--------------------------------"

if [[ "$OS" == "macos" ]]; then
    if [[ -d "/Applications/Helium.app" ]]; then
        brew uninstall --cask helium-browser
        success "Helium Browser removed."
    else
        warn "Not installed: helium-browser"
    fi

elif [[ "$OS" == "debian" ]]; then
    if command -v helium &>/dev/null; then
        sudo apt-get remove -y helium-bin
        sudo apt-get autoremove -y
        sudo rm -f /etc/apt/sources.list.d/helium.list
        sudo rm -f /usr/share/keyrings/helium.gpg
        success "Helium Browser removed."
    else
        warn "Not installed: helium-bin"
    fi

else
    error "Unsupported OS: ${OS}"; exit 1
fi


