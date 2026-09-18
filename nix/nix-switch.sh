#!/usr/bin/env bash
# Applies the flake config: darwin-rebuild on macOS, home-manager switch on Ubuntu.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"
FLAKE_DIR="$SCRIPT_DIR"

# sudo's secure_path / a bash script's PATH don't reliably include Nix's profile bin
# dir — resolve absolute paths once and export the dir, since the home-manager/
# nix-darwin activation scripts also shell out to nix-build/nix-store/etc. by bare name.
NIX_BIN="$(command -v nix || echo /nix/var/nix/profiles/default/bin/nix)"
NIX_BIN_DIR="$(dirname "$NIX_BIN")"
export PATH="$NIX_BIN_DIR:$PATH"

echo "--------------------------------"
cog_msg "Applying Nix generation ($OS)..."
echo "--------------------------------"

if [[ "$OS" == "macos" ]]; then
    # sudo's secure_path doesn't include Nix's profile bin dir — resolve the absolute
    # path before invoking under sudo, or `sudo: nix: command not found` results.

    # Check the fixed system-activation path, not `command -v` — the latter depends on
    # the invoking shell's $PATH (a bash script doesn't inherit zsh's /etc/zshrc PATH
    # additions the way an interactive shell does), causing false "not found" positives
    # that fall through to the slow, UNPINNED `nix-darwin/master` bootstrap below —
    # which ignores flake.lock and can silently apply a different nix-darwin version.
    DARWIN_REBUILD="/run/current-system/sw/bin/darwin-rebuild"

    if [[ -x "$DARWIN_REBUILD" ]]; then
        sudo "$DARWIN_REBUILD" switch --flake "${FLAKE_DIR}#MacbookAir"
    else
        # True first run only — darwin-rebuild doesn't exist on disk yet. Build it from
        # THIS flake's locked nix-darwin input (not the unpinned `nix-darwin/master`),
        # so the very first activation uses the same version every subsequent one does.
        warn "darwin-rebuild not found — bootstrapping nix-darwin for the first time"
        SYSTEM_PATH="$("$NIX_BIN" build "${FLAKE_DIR}#darwinConfigurations.MacbookAir.system" --no-link --print-out-paths)"
        sudo "${SYSTEM_PATH}/sw/bin/darwin-rebuild" switch --flake "${FLAKE_DIR}#MacbookAir"
    fi

elif [[ "$OS" == "debian" ]]; then
    if command -v home-manager &>/dev/null; then
        home-manager switch --flake "${FLAKE_DIR}#$(whoami)@ubuntu"
    else
        # True first run only — home-manager doesn't exist on disk yet. `nix run
        # home-manager -- switch` would pull the unpinned nix-community/home-manager
        # default flake instead of THIS flake's locked input (same class of bug fixed
        # for darwin-rebuild above). Build the activation package from our own locked
        # flake input instead, so the very first activation matches every later one.
        warn "home-manager not found — bootstrapping for the first time"
        ACTIVATION_PKG="$("$NIX_BIN" build "${FLAKE_DIR}#homeConfigurations.$(whoami)@ubuntu.activationPackage" --no-link --print-out-paths)"
        "${ACTIVATION_PKG}/activate"
    fi

else
    error "Unsupported OS: ${OS}"; exit 1
fi

success "Nix generation applied"
