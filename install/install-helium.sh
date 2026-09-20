#!/usr/bin/env bash
# Installs Helium Browser (https://helium.computer), a privacy-focused
# ungoogled-Chromium fork. Not part of the Nix/asdf migration — no nixpkgs
# derivation exists, so it stays on each OS's native package manager.
# macOS: Homebrew cask. Ubuntu: imputnet's official APT repo (no snap build).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

# ------------------------------------------
# macOS — Homebrew cask
# ------------------------------------------
install_macos() {
    if command -v helium &>/dev/null || [[ -d "/Applications/Helium.app" ]]; then
        warn "Already installed: helium-browser"
        exit 0
    fi

    brew install --cask helium-browser
    success "Helium Browser installed."
}

# ------------------------------------------
# Ubuntu — imputnet's official APT repo
# ------------------------------------------
# Helium's package-signing key. Pinned as a full fingerprint: an APT trust
# anchor is equivalent to root code execution for every future apt install, so
# fetch-and-trust without verification is not good enough. Fingerprint from
# https://github.com/imputnet/helium-linux#signature.
HELIUM_GPG_FPR="BE677C1989D35EAB2C5F26C9351601AD01D6378E"

add_helium_apt_repo() {
    [[ -f /etc/apt/sources.list.d/helium.list ]] && return 0

    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /usr/share/keyrings

    # Download as the unprivileged user and verify before it becomes a trust
    # anchor — never `sudo curl`, which would parse attacker-reachable TLS and
    # HTTP input as root.
    local key
    key="$(mktemp)"
    trap 'rm -f "$key"' RETURN
    curl -fsSL https://raw.githubusercontent.com/imputnet/helium-linux/main/pubkey.asc -o "$key"

    if ! gpg --show-keys --with-colons "$key" \
        | awk -F: '/^fpr:/ { print $10 }' \
        | grep -qx "$HELIUM_GPG_FPR"; then
        error "Helium GPG key fingerprint mismatch — refusing to trust it."
        error "Expected ${HELIUM_GPG_FPR}. Got:"
        gpg --show-keys --with-colons "$key" | awk -F: '/^fpr:/ { print "  " $10 }'
        return 1
    fi

    sudo gpg --dearmor -o /usr/share/keyrings/helium.gpg < "$key"
    echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/helium.gpg] https://pkg.helium.computer/deb stable main" \
        | sudo tee /etc/apt/sources.list.d/helium.list > /dev/null
    sudo apt-get update
}

install_debian() {
    if command -v helium &>/dev/null; then
        warn "Already installed: helium-bin ($(helium --version 2>/dev/null | head -1))"
        exit 0
    fi

    add_helium_apt_repo
    sudo apt-get install -y helium-bin
    success "Helium Browser installed."
}

# --------------------------------------------------
# Main
# --------------------------------------------------
main() {
    echo "--------------------------------"
    cog_msg "Installing Helium Browser..."
    echo "--------------------------------"

    if [[ "$OS" == "macos" ]]; then
        install_macos
    elif [[ "$OS" == "debian" ]]; then
        install_debian
    else
        error "Unsupported OS: ${OS}"; exit 1
    fi
}

main "$@"
