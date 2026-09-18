#!/usr/bin/env bash
# Removes all Python versions installed by install-python.sh. uv itself is
# Nix-managed (nix/home/packages.nix) — not removed here; remove it from
# packages.nix and re-run darwin-rebuild/home-manager switch to remove uv itself.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"

echo "--------------------------------"
cog_msg "Removing uv-managed Python versions..."
echo "--------------------------------"

if ! command -v uv &>/dev/null; then
    warn "Not installed: uv"
    exit 0
fi

uv python uninstall --all
success "uv-managed Python versions removed."
