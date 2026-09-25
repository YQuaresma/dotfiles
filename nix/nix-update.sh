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

# The nixpkgs input (nix/flake.nix) is pinned to a specific commit, not
# nixos-unstable, working around NixOS/nixpkgs#566395 (asdf-vm 0.20.1's
# upstream release tag was deleted, 404ing the source fetch) until
# NixOS/nixpkgs#566396 (asdf-vm 0.20.1 -> 0.20.2) merges. Check its status
# on every run so the pin doesn't linger unnoticed once it's fixed
# upstream. Best-effort: no GitHub token, so this is subject to the
# unauthenticated rate limit and silently skipped if unreachable — never
# blocks the update.
ASDF_PIN_JSON_BIN="$(command -v gojq || command -v jq || true)"
if [[ -n "$ASDF_PIN_JSON_BIN" ]]; then
    ASDF_PIN_PR_STATE="$(curl -fsS --max-time 5 \
        "https://api.github.com/repos/NixOS/nixpkgs/pulls/566396" 2>/dev/null \
        | "$ASDF_PIN_JSON_BIN" -r '.merged_at // "null"' 2>/dev/null || true)"
else
    ASDF_PIN_PR_STATE=""
fi
if [[ -n "$ASDF_PIN_PR_STATE" && "$ASDF_PIN_PR_STATE" != "null" ]]; then
    warn "NixOS/nixpkgs#566396 merged (${ASDF_PIN_PR_STATE}) — nix/flake.nix's"
    warn "nixpkgs pin can now move back to \"github:NixOS/nixpkgs/nixos-unstable\"."
    warn "https://github.com/NixOS/nixpkgs/pull/566396"
fi

echo "--------------------------------"
cog_msg "Updating Nix flake inputs..."
echo "--------------------------------"

# flake.lock is untracked (see .gitignore), so keep a copy to diff against:
# `nix flake update` pulls nixpkgs/home-manager/nix-darwin to upstream HEAD and
# nix-switch.sh then activates the result with sudo on macOS. Show what moved
# before applying it. A first-ever run (no flake.lock yet) has nothing to diff
# but is exactly as consequential as an input bump — it bootstraps sudo-applied
# system activation from scratch — so it goes through the identical tty/confirm
# gate rather than falling into the unguarded "nothing changed" path.
LOCK="${FLAKE_DIR}/flake.lock"
LOCK_BEFORE=""
FIRST_RUN=0
if [[ -f "$LOCK" ]]; then
    LOCK_BEFORE="$(mktemp)"
    trap 'rm -f "$LOCK_BEFORE"' EXIT
    cp "$LOCK" "$LOCK_BEFORE"
else
    FIRST_RUN=1
fi

"$NIX_BIN" flake update --flake "$FLAKE_DIR"

INPUTS_CHANGED=0
if [[ -n "$LOCK_BEFORE" ]] && ! diff -q "$LOCK_BEFORE" "$LOCK" >/dev/null 2>&1; then
    INPUTS_CHANGED=1
fi

if (( FIRST_RUN )) || (( INPUTS_CHANGED )); then
    if (( INPUTS_CHANGED )); then
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
    else
        highlight "First run — no existing flake.lock, nothing has been activated yet."
    fi

    if [[ "${NIX_UPDATE_ASSUME_YES:-0}" == "1" ]]; then
        info "NIX_UPDATE_ASSUME_YES=1 — applying without prompting."
    elif [[ ! -t 0 ]]; then
        warn "Not an interactive shell — flake.lock written but NOT applied."
        warn "Re-run interactively, or set NIX_UPDATE_ASSUME_YES=1 to apply unreviewed input bumps."
        exit 0
    elif ! confirm "Build and activate this configuration?"; then
        warn "Declined — flake.lock written but not applied. Run nix-switch.sh when ready."
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
