#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
# shellcheck source=install/apps-gui.list.sh
source "${SCRIPT_DIR}/apps-gui.list.sh"
OS="$(detect_os)"

if [[ "$OS" == "macos" ]]; then
    echo "--------------------------------"
    cog_msg "Installing Brew cask apps..."
    echo "--------------------------------"

    for pkg in "${GUI_CASKS[@]}"; do
        if brew list --cask "$pkg" &>/dev/null; then
            warn "Already installed: $pkg"
        else
            brew install --cask "$pkg" --adopt && success "Installed: $pkg" || error "Failed to install: $pkg — continuing..."
        fi
    done

elif [[ "$OS" == "debian" ]]; then
    echo "--------------------------------"
    cog_msg "Installing Snap applications..."
    echo "--------------------------------"

    for entry in "${GUI_SNAPS[@]}"; do
        pkg="$(snap_pkg_name "$entry")"
        flags="$(snap_pkg_flags "$entry")"
        if snap list "$pkg" &>/dev/null; then
            warn "Already installed: $pkg"
        else
            # shellcheck disable=SC2086
            sudo snap install $flags "$pkg" && success "Installed: $pkg" || error "Failed to install: $pkg — continuing..."
        fi
    done

else
    error "Unsupported OS: ${OS}"; exit 1
fi

success "GUI app installation complete."
