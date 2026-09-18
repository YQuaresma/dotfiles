#!/usr/bin/env bash
# Removes GUI apps installed by install-apps-gui.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

echo "--------------------------------"
cog_msg "Removing GUI apps..."
echo "--------------------------------"

if [[ "$OS" == "macos" ]]; then
    casks=(
      "claude"
      "clocker"
      "drawio"
      "firefox"
      "font-fira-code-nerd-font"
      "font-inconsolata-nerd-font"
      "font-meslo-lg-nerd-font"
      "gitkraken"
      "google-chrome"
      "jetbrains-toolbox"
      "meld"
      "ngrok"
      "notion"
      "postman"
      "rectangle"
      "sourcetree"
      "sublime-text"
      "visual-studio-code"
      "whatsapp"
    )

    for pkg in "${casks[@]}"; do
        if brew list --cask "$pkg" &>/dev/null; then
            brew uninstall --cask "$pkg" && success "Removed: $pkg" || error "Failed to remove: $pkg — continuing..."
        else
            warn "Not installed: $pkg"
        fi
    done

elif [[ "$OS" == "debian" ]]; then
    snap_apps=(
      "1password" "code" "drawio" "firefox" "gitkraken"
      "ngrok" "notion-desktop" "postman" "sublime-text"
    )

    for pkg in "${snap_apps[@]}"; do
        if snap list "$pkg" &>/dev/null 2>&1; then
            sudo snap remove "$pkg" && success "Removed: $pkg" || error "Failed to remove: $pkg — continuing..."
        else
            warn "Not installed: $pkg"
        fi
    done

else
    error "Unsupported OS: ${OS}"; exit 1
fi

success "GUI app removal complete."
