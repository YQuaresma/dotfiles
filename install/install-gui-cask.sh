#!/usr/bin/env bash
# Installs GUI apps via Homebrew casks. macOS only — split out of
# install-gui-snap.sh so each package manager has its own script.
#
# GUI_CASKS must stay in sync with remove-gui-cask.sh's copy — an "undo"
# script that removes things it never installed, or leaves behind things it
# did, is worse than one that does nothing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

if [[ "$OS" != "macos" ]]; then
    warn "install-gui-cask.sh is macOS-only — see install-gui-snap.sh (Snap) and install-gui-apt.sh (apt) on Ubuntu."
    exit 0
fi

GUI_CASKS=(
    "1password"
    "balenaetcher"
    "claude"
    "drawio"
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
    "sublime-text"
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
