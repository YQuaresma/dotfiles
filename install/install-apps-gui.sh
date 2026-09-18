#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

if [[ "$OS" == "macos" ]]; then
    echo "--------------------------------"
    cog_msg "Installing Brew cask apps..."
    echo "--------------------------------"

    casks=(
      "1password"
      "balenaetcher"
      "claude"
      "drawio"
      "firefox"
      "gitkraken"
      "google-chrome"
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
    )

    for pkg in "${casks[@]}"; do
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

    snap_apps=(
      "1password"
      "code --classic"
      "drawio"
      "firefox"
      "gitkraken --classic"
      "jetbrains-toolbox --beta"
      "ngrok"
      "notion-desktop"
      "postman"
      "sublime-text --classic"
    )

    for entry in "${snap_apps[@]}"; do
        pkg="${entry%% *}"
        flags="${entry#* }"
        [ "$flags" = "$pkg" ] && flags=""
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
