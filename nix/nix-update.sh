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

# flake.lock is untracked (see .gitignore), so keep a copy to diff against:
# `nix flake update` pulls nixpkgs/home-manager/nix-darwin to upstream HEAD and
# nix-switch.sh then activates the result with sudo on macOS. Show what moved
# before applying it.
LOCK="${FLAKE_DIR}/flake.lock"
LOCK_BEFORE=""
if [[ -f "$LOCK" ]]; then
    LOCK_BEFORE="$(mktemp)"
    trap 'rm -f "$LOCK_BEFORE"' EXIT
    cp "$LOCK" "$LOCK_BEFORE"
fi

"$NIX_BIN" flake update --flake "$FLAKE_DIR"

if [[ -n "$LOCK_BEFORE" ]] && ! diff -q "$LOCK_BEFORE" "$LOCK" >/dev/null 2>&1; then
    highlight "Flake inputs moved:"
    # Prefer a per-input revision diff; fall back to a raw lock diff when no JSON
    # tool is on PATH (gojq/jq are Nix-provided, so absent on a first run).
    JSON_BIN="$(command -v gojq || command -v jq || true)"
    if [[ -n "$JSON_BIN" ]]; then
        REV_FILTER='.nodes|to_entries[]|select(.value.locked)|"\(.key) \(.value.locked.rev // .value.locked.narHash)"'
        diff <("$JSON_BIN" -r "$REV_FILTER" "$LOCK_BEFORE" 2>/dev/null || true) \
             <("$JSON_BIN" -r "$REV_FILTER" "$LOCK" 2>/dev/null || true) \
            | sed 's/^/    /' || true
    else
        diff "$LOCK_BEFORE" "$LOCK" | sed 's/^/    /' || true
    fi

    if [[ "${NIX_UPDATE_ASSUME_YES:-0}" == "1" ]]; then
        info "NIX_UPDATE_ASSUME_YES=1 — applying without prompting."
    elif [[ ! -t 0 ]]; then
        warn "Not an interactive shell — inputs updated but NOT applied."
        warn "Re-run interactively, or set NIX_UPDATE_ASSUME_YES=1 to apply unreviewed input bumps."
        exit 0
    elif ! confirm "Build and activate this configuration?"; then
        warn "Declined — inputs updated but not applied. Run nix-switch.sh when ready."
        exit 0
    fi
else
    tick "Flake inputs unchanged."
fi

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
