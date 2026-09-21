#!/usr/bin/env bash
# Installs GUI apps via Homebrew casks. macOS only — Ubuntu gets these via
# install-gui-ubuntu.sh (apt repos/packages/tarballs/installers).
#
# GUI_CASKS must stay in sync with remove-gui-macos.sh's copy — an "undo"
# script that removes things it never installed, or leaves behind things it
# did, is worse than one that does nothing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

if [[ "$OS" != "macos" ]]; then
    warn "install-gui-macos.sh is macOS-only — see install-gui-ubuntu.sh on Ubuntu."
    exit 0
fi

GUI_CASKS=(
    "1password"
    "balenaetcher"
    "claude"
    "firefox"
    "ghostty"
    "gitkraken"
    "google-chrome"
    "helium-browser"
    "jetbrains-toolbox"
    "meetingbar"
    "meld"
    "ngrok"
    "notion"
    "postman"
    "rectangle"
    "sourcetree"
    "visual-studio-code"
    "whatsapp"
    "zed"
)

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

success "GUI Brew cask installation complete."
