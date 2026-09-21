#!/usr/bin/env bash
# Removes apps installed by install-gui-apt.sh: purges each package plus its
# apt repo/keyring/pin files (or, for Zed, its ~/.local install — see below).
# Ubuntu-only (install-gui-apt.sh is a no-op on macOS, where these stay
# Homebrew casks managed by remove-gui-cask.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

# remove_apt_repo <package> <list-file> <keyring-path> [extra-file...]
remove_apt_repo() {
    local pkg="$1" list_file="$2" keyring_path="$3"
    shift 3

    if command -v "$pkg" &>/dev/null || dpkg -s "$pkg" &>/dev/null 2>&1; then
        sudo apt-get remove -y "$pkg" || true
    else
        warn "Not installed: $pkg"
    fi

    sudo rm -f "$list_file" "$keyring_path" "$@"
}

main() {
    if [[ "$OS" != "debian" ]]; then
        warn "remove-gui-apt.sh is Ubuntu-only — these apps are Homebrew casks on macOS, use remove-gui-cask.sh."
        exit 0
    fi

    echo "--------------------------------"
    cog_msg "Removing GUI apt apps..."
    echo "--------------------------------"

    remove_apt_repo 1password \
        /etc/apt/sources.list.d/1password.list \
        /usr/share/keyrings/1password-archive-keyring.gpg

    remove_apt_repo firefox \
        /etc/apt/sources.list.d/mozilla.list \
        /usr/share/keyrings/packages.mozilla.org.gpg \
        /etc/apt/preferences.d/mozilla-firefox

    if command -v ghostty &>/dev/null; then
        sudo apt-get remove -y ghostty || true
    else
        warn "Not installed: ghostty"
    fi

    if command -v gitkraken &>/dev/null; then
        sudo apt-get remove -y gitkraken || true
    else
        warn "Not installed: gitkraken"
    fi

    remove_apt_repo helium-bin \
        /etc/apt/sources.list.d/helium.list \
        /usr/share/keyrings/helium.gpg

    remove_apt_repo ngrok \
        /etc/apt/sources.list.d/ngrok.list \
        /usr/share/keyrings/ngrok-archive-keyring.gpg

    remove_apt_repo sublime-text \
        /etc/apt/sources.list.d/sublime-text.list \
        /usr/share/keyrings/sublimehq-archive-keyring.gpg

    remove_apt_repo code \
        /etc/apt/sources.list.d/vscode.list \
        /usr/share/keyrings/microsoft-archive-keyring.gpg

    # Zed — no apt/dpkg package to remove; zed.dev's installer just unpacks a
    # tarball to ~/.local (see install-gui-apt.sh's install_zed comment).
    if command -v zed &>/dev/null; then
        rm -f "$HOME/.local/bin/zed"
        rm -rf "$HOME/.local/zed.app"
        rm -f "$HOME/.local/share/applications/dev.zed.Zed.desktop"
        success "Removed: zed"
    else
        warn "Not installed: zed"
    fi

    sudo apt-get autoremove -y
    sudo apt-get update

    success "GUI apt apps removed."
}

main "$@"
