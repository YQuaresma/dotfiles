#!/usr/bin/env bash
# Installs Ghostty (https://ghostty.org). Not part of the Nix/asdf migration — no
# from-source nixpkgs derivation works on either OS (macOS needs Swift 6/xcodebuild,
# unsupported; Ubuntu's Nix build's pinned GTK/Mesa/libwayland stack breaks EGL
# context creation at runtime), so it stays on each OS's native package manager.
# macOS: via Homebrew cask. Ubuntu: via apt (official repo, Ubuntu 26.04+ only).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

echo "--------------------------------"
cog_msg "Installing Ghostty..."
echo "--------------------------------"

# Skip if already installed
if command -v ghostty &>/dev/null; then
    warn "Already installed: ghostty ($(ghostty --version 2>/dev/null | head -1))"
    exit 0
fi

if [[ "$OS" == "macos" ]]; then
    brew install --cask ghostty

elif [[ "$OS" == "debian" ]]; then
    export DEBIAN_FRONTEND=noninteractive
    sudo apt install -y ghostty < /dev/null

else
    error "Unsupported OS: ${OS}"; exit 1
fi

success "Ghostty installed: $(ghostty --version 2>/dev/null | head -1)"
