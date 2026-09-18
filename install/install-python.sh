#!/usr/bin/env bash
# Installs the latest Python release via uv. uv itself is Nix-managed
# (nix/home/packages.nix) — this script only installs a Python interpreter with it,
# independent of brew/apt.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"

echo "--------------------------------"
cog_msg "Installing Python (via uv)..."
echo "--------------------------------"

if ! command -v uv &>/dev/null; then
    error "uv not found — run 'sys-update.sh' (or 'darwin-rebuild switch' / 'home-manager switch') first."
    exit 1
fi

# Skip if a Python version is already installed
if uv python list --only-installed 2>/dev/null | grep -q .; then
    warn "Already installed: uv ($(uv --version)) with Python"
    exit 0
fi

uv python install
success "Python installed: $(uv python list | head -1)"
