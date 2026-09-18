#!/usr/bin/env bash
# Installs omp (Oh My Pi — https://github.com/can1357/oh-my-pi). Not part of the
# Nix/asdf migration — not in nixpkgs, and the upstream install paths below already
# auto-update (brew tap / curl installer), so a hand-maintained Nix derivation would
# trade that for manual version+sha256 bumps on every release.
# macOS: via the can1357/tap Homebrew tap. Ubuntu: via the official curl installer
# (installs a prebuilt binary to ~/.local/bin).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

echo "--------------------------------"
cog_msg "Installing omp (Oh My Pi)..."
echo "--------------------------------"

# Skip if already installed
if command -v omp &>/dev/null; then
    warn "Already installed: omp ($(omp --version 2>/dev/null | head -1))"
    exit 0
fi

if [[ "$OS" == "macos" ]]; then
    brew tap can1357/tap
    brew install can1357/tap/omp

elif [[ "$OS" == "debian" ]]; then
    curl -fsSL https://omp.sh/install | sh

else
    error "Unsupported OS: ${OS}"; exit 1
fi

success "omp installed: $(omp --version 2>/dev/null | head -1)"
