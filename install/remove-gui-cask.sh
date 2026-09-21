#!/usr/bin/env bash
# Removes GUI apps installed by install-gui-cask.sh. macOS only.
#
# GUI_CASKS must stay in sync with install-gui-cask.sh's copy — an "undo"
# script that removes things it never installed, or leaves behind things it
# did, is worse than one that does nothing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

if [[ "$OS" != "macos" ]]; then
    warn "remove-gui-cask.sh is macOS-only — see remove-gui-ubuntu.sh on Ubuntu."
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
cog_msg "Removing GUI Brew cask apps..."
echo "--------------------------------"

for pkg in "${GUI_CASKS[@]}"; do
    if brew list --cask "$pkg" &>/dev/null; then
        brew uninstall --cask "$pkg" && success "Removed: $pkg" || error "Failed to remove: $pkg — continuing..."
    else
        warn "Not installed: $pkg"
    fi
done

success "GUI Brew cask removal complete."
