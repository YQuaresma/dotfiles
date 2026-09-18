#!/usr/bin/env bash
# Installs Nix via the Determinate Systems installer (flakes + nix-command on by default).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"

echo "--------------------------------"
cog_msg "Installing Nix (Determinate Systems installer)..."
echo "--------------------------------"

if command -v nix &>/dev/null; then
    warn "Already installed: Nix ($(nix --version))"
    exit 0
fi

curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

success "Nix installed — restart your shell, then run nix-switch.sh"
