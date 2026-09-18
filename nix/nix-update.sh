#!/usr/bin/env bash
# Updates the flake inputs, applies the new generation, and prunes old generations.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"
FLAKE_DIR="$SCRIPT_DIR"
GC_OLDER_THAN="${NIX_GC_OLDER_THAN:-14d}"   # override: NIX_GC_OLDER_THAN=7d nix-update.sh

# Resolve nix's absolute path once — a bare `nix`/`nix-collect-garbage` lookup fails in
# any shell that hasn't sourced /etc/zshrc (non-interactive/non-login shells, cron, etc.),
# same class of issue fixed in nix-switch.sh. Both binaries live in the same directory.
NIX_BIN="$(command -v nix || echo /nix/var/nix/profiles/default/bin/nix)"
NIX_BIN_DIR="$(dirname "$NIX_BIN")"
export PATH="$NIX_BIN_DIR:$PATH"

echo "--------------------------------"
cog_msg "Updating Nix flake inputs..."
echo "--------------------------------"
"$NIX_BIN" flake update --flake "$FLAKE_DIR"

"${SCRIPT_DIR}/nix-switch.sh"

echo "--------------------------------"
cog_msg "Garbage collecting generations older than ${GC_OLDER_THAN}..."
echo "--------------------------------"
if [[ "$OS" == "macos" ]]; then
    # System (root-owned) profile generations require sudo to collect.
    sudo "$NIX_BIN" store gc 2>/dev/null || true
    sudo "$NIX_BIN" profile wipe-history --older-than "$GC_OLDER_THAN" \
        --profile /nix/var/nix/profiles/system 2>/dev/null || true

elif [[ "$OS" == "debian" ]]; then
    home-manager expire-generations "-${GC_OLDER_THAN}" 2>/dev/null || true

else
    error "Unsupported OS: ${OS}"; exit 1
fi
nix-collect-garbage --delete-older-than "$GC_OLDER_THAN"

success "Nix packages updated, generations older than ${GC_OLDER_THAN} pruned"
