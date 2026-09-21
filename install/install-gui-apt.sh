#!/usr/bin/env bash
# Installs GUI apps via their official Ubuntu install method — an apt repo,
# a plain apt package, a downloaded .deb, or (Zed) an official curl
# installer with no apt/dpkg involvement at all. macOS already gets these
# via Homebrew casks in install-gui-cask.sh — this script is Ubuntu-only.
#
# Most apps below have an official, vendor-published apt repo that GUI_SNAPS
# previously covered via Snap. See install-gui-snap.sh for the apps that
# stayed on Snap because no official APT path exists (draw.io, JetBrains
# Toolbox, Notion, Postman).
#
# GPG fingerprints are pinned per app, same convention as install-helium's
# old fingerprint (see install_helium below): an APT trust anchor is
# equivalent to root code execution for every future apt install, so
# fetch-and-trust without verification is not good enough. Fingerprints
# below were captured directly from each vendor's live key URL (see each
# function) — re-verify against the vendor's own docs if a future key
# rotation trips the mismatch check.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

# add_apt_repo <list-file> <key-url> <expected-fingerprint> <keyring-path> <repo-line>
# Idempotent (skips if list-file already exists) and fail-closed: refuses to
# trust a key whose fingerprint doesn't match.
add_apt_repo() {
    local list_file="$1" key_url="$2" expected_fpr="$3" keyring_path="$4" repo_line="$5"
    [[ -f "$list_file" ]] && return 0

    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d "$(dirname "$keyring_path")"

    local key
    key="$(mktemp)"
    trap 'rm -f "$key"' RETURN
    curl -fsSL "$key_url" -o "$key"

    if ! gpg --show-keys --with-colons "$key" \
        | awk -F: '/^fpr:/ { print $10 }' \
        | grep -qx "$expected_fpr"; then
        error "GPG key fingerprint mismatch for ${list_file} — refusing to trust it."
        error "Expected ${expected_fpr}. Got:"
        gpg --show-keys --with-colons "$key" | awk -F: '/^fpr:/ { print "  " $10 }'
        return 1
    fi

    sudo gpg --dearmor -o "$keyring_path" < "$key"
    echo "$repo_line" | sudo tee "$list_file" > /dev/null
}

# ------------------------------------------
# 1Password — official repo
# https://support.1password.com/install-linux/
# ------------------------------------------
install_1password() {
    if command -v 1password &>/dev/null; then
        warn "Already installed: 1password"
        return 0
    fi
    add_apt_repo /etc/apt/sources.list.d/1password.list \
        https://downloads.1password.com/linux/keys/1password.asc \
        3FEF9748469ADBE15DA7CA80AC2D62742012EA22 \
        /usr/share/keyrings/1password-archive-keyring.gpg \
        "deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main"
    sudo apt-get update
    sudo apt-get install -y 1password && success "Installed: 1password" || error "Failed to install: 1password — continuing..."
}

# ------------------------------------------
# Firefox — official Mozilla repo
# https://support.mozilla.org/en-US/kb/install-firefox-linux
# Ubuntu ships a transitional "firefox" deb stub that redirects to the Snap;
# the pin below forces APT to prefer Mozilla's real .deb once the repo exists.
# ------------------------------------------
install_firefox() {
    add_apt_repo /etc/apt/sources.list.d/mozilla.list \
        https://packages.mozilla.org/apt/repo-signing-key.gpg \
        35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3 \
        /usr/share/keyrings/packages.mozilla.org.gpg \
        "deb [signed-by=/usr/share/keyrings/packages.mozilla.org.gpg] https://packages.mozilla.org/apt mozilla main"

    if [[ ! -f /etc/apt/preferences.d/mozilla-firefox ]]; then
        printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' \
            | sudo tee /etc/apt/preferences.d/mozilla-firefox > /dev/null
    fi

    sudo apt-get update
    sudo apt-get install -y firefox && success "Installed: firefox" || error "Failed to install: firefox — continuing..."
}

# ------------------------------------------
# Ghostty — official Ubuntu apt repo (Ubuntu 26.04+ only; no external repo
# or key needed, it's in the default archive)
# ------------------------------------------
install_ghostty() {
    if command -v ghostty &>/dev/null; then
        warn "Already installed: ghostty"
        return 0
    fi
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get install -y ghostty < /dev/null && success "Installed: ghostty" || error "Failed to install: ghostty — continuing..."
}

# ------------------------------------------
# GitKraken — NO official APT repo (verified live: the commonly cited
# release.gitkraken.com/linux/gitkraken-archive-keyring.gpg 404s, and
# help.gitkraken.com's current install guide only documents a one-off .deb
# download). Falls back to that official .deb, matching Ghostty's plain apt
# install and install_helium's repo-based install below — every other app
# in this file has SOME apt/dpkg touchpoint, GitKraken's is just weaker
# (a one-off download, not a repo apt can auto-update from). No GPG
# signature exists to pin — same HTTPS-transport-only trust tier as
# install-omp.sh's curl installer and this file's own install_zed.
# Re-run this function to pick up a newer release; `apt` alone won't see
# updates since there's no repo.
# ------------------------------------------
install_gitkraken() {
    if command -v gitkraken &>/dev/null; then
        warn "Already installed: gitkraken"
        return 0
    fi
    local deb
    deb="$(mktemp --suffix=.deb)"
    trap 'rm -f "$deb"' RETURN
    curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL \
        https://release.gitkraken.com/linux/gitkraken-amd64.deb -o "$deb"
    sudo apt-get install -y "$deb" && success "Installed: gitkraken" || error "Failed to install: gitkraken — continuing..."
}

# ------------------------------------------
# Helium Browser — imputnet's official apt repo (no snap build)
# https://github.com/imputnet/helium-linux#signature
# ------------------------------------------
install_helium() {
    if command -v helium &>/dev/null; then
        warn "Already installed: helium-bin"
        return 0
    fi
    add_apt_repo /etc/apt/sources.list.d/helium.list \
        https://raw.githubusercontent.com/imputnet/helium-linux/main/pubkey.asc \
        BE677C1989D35EAB2C5F26C9351601AD01D6378E \
        /usr/share/keyrings/helium.gpg \
        "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/helium.gpg] https://pkg.helium.computer/deb stable main"
    sudo apt-get update
    sudo apt-get install -y helium-bin && success "Installed: helium-bin" || error "Failed to install: helium-bin — continuing..."
}

# ------------------------------------------
# ngrok — official repo
# https://ngrok.com/download/linux
# ------------------------------------------
install_ngrok() {
    if command -v ngrok &>/dev/null; then
        warn "Already installed: ngrok"
        return 0
    fi
    add_apt_repo /etc/apt/sources.list.d/ngrok.list \
        https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
        F0271FCF712CF2E39901F1A30E61D3BBAAEE37FE \
        /usr/share/keyrings/ngrok-archive-keyring.gpg \
        "deb [signed-by=/usr/share/keyrings/ngrok-archive-keyring.gpg] https://ngrok-agent.s3.amazonaws.com bookworm main"
    sudo apt-get update
    sudo apt-get install -y ngrok && success "Installed: ngrok" || error "Failed to install: ngrok — continuing..."
}

# ------------------------------------------
# Sublime Text — official repo
# https://www.sublimetext.com/docs/linux_repositories.html
# ------------------------------------------
install_sublime_text() {
    if command -v subl &>/dev/null; then
        warn "Already installed: sublime-text"
        return 0
    fi
    add_apt_repo /etc/apt/sources.list.d/sublime-text.list \
        https://download.sublimetext.com/sublimehq-pub.gpg \
        1EDDE2CDFC025D17F6DA9EC0ADAE6AD28A8F901A \
        /usr/share/keyrings/sublimehq-archive-keyring.gpg \
        "deb [signed-by=/usr/share/keyrings/sublimehq-archive-keyring.gpg] https://download.sublimetext.com/ apt/stable/"
    sudo apt-get update
    sudo apt-get install -y sublime-text && success "Installed: sublime-text" || error "Failed to install: sublime-text — continuing..."
}

# ------------------------------------------
# VS Code — official Microsoft repo
# https://code.visualstudio.com/docs/setup/linux
# ------------------------------------------
install_vscode() {
    if command -v code &>/dev/null; then
        warn "Already installed: code"
        return 0
    fi
    add_apt_repo /etc/apt/sources.list.d/vscode.list \
        https://packages.microsoft.com/keys/microsoft.asc \
        BC528686B50D79E339D3721CEB3E94ADBE1229CF \
        /usr/share/keyrings/microsoft-archive-keyring.gpg \
        "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/code stable main"
    sudo apt-get update
    sudo apt-get install -y code && success "Installed: code" || error "Failed to install: code — continuing..."
}

# ------------------------------------------
# Zed — NO apt/dpkg involvement at all (unlike every app above, including
# GitKraken's downloaded-then-apt-installed .deb). zed.dev's official
# install.sh unpacks a tarball straight to ~/.local and symlinks
# ~/.local/bin/zed — nixpkgs' zed-editor also exists but ships a `zeditor`
# binary whose Vulkan/GPU surface creation proved brittle against
# group-membership changes and long-running server processes on this
# machine, so this script uses the official installer instead. No GPG
# signature to pin — same HTTPS-transport-only trust tier as
# install-omp.sh's curl installer.
# ------------------------------------------
install_zed() {
    if command -v zed &>/dev/null; then
        warn "Already installed: zed"
        return 0
    fi
    local zed_installer
    zed_installer="$(mktemp)"
    trap 'rm -f "$zed_installer"' RETURN
    curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL \
        https://zed.dev/install.sh -o "$zed_installer"
    sh "$zed_installer" && success "Installed: zed" || error "Failed to install: zed — continuing..."
}

# --------------------------------------------------
# Main
# --------------------------------------------------
main() {
    if [[ "$OS" != "debian" ]]; then
        warn "install-gui-apt.sh is Ubuntu-only — these apps are already Homebrew casks via install-gui-cask.sh on macOS."
        exit 0
    fi

    echo "--------------------------------"
    cog_msg "Installing GUI apps via APT..."
    echo "--------------------------------"

    install_1password
    install_firefox
    install_ghostty
    install_gitkraken
    install_helium
    install_ngrok
    install_sublime_text
    install_vscode
    install_zed

    success "GUI apt app installation complete."
}

main "$@"
