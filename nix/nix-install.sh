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

# This installer escalates to root: it creates /nix, installs the build daemon
# (launchd on macOS, systemd on Ubuntu) and edits /etc/nix/nix.conf. Determinate
# publishes no checksum for the bootstrap script, so pin the scheme on the
# request and on redirects, and download before executing so a truncated
# transfer cannot be partially run.
warn "The Nix installer runs with root privileges (daemon, /nix, /etc/nix)."
nix_installer="$(mktemp)"
trap 'rm -f "$nix_installer"' EXIT
curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL \
    https://install.determinate.systems/nix -o "$nix_installer"
sh "$nix_installer" install

success "Nix installed — restart your shell, then run nix-switch.sh"
