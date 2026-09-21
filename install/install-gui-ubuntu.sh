#!/usr/bin/env bash
# Installs GUI apps via their official Ubuntu install method — an apt repo,
# a plain apt package, a downloaded .deb, JetBrains' official checksummed
# tarball, Postman's official (unchecksummed) tarball, or (Zed) an official
# curl installer with no apt/dpkg involvement at all. macOS already gets
# these via Homebrew casks in install-gui-cask.sh — this script is
# Ubuntu-only.
#
# Most apps below have an official, vendor-published apt repo that GUI_SNAPS
# previously covered via Snap. See install-gui-snap.sh for the apps that
# stayed on Snap because no official install path exists at all (Notion —
# no official Linux app whatsoever, not even a tarball).
# JetBrains Toolbox has neither an apt path nor a working Snap (the only
# Snap under that name was an unofficial, non-functional repackaging — see
# install_jetbrains_toolbox below), so it uses JetBrains' own releases API.
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

    # Explicit cleanup on both exit paths below, not `trap ... RETURN`: that
    # trap isn't scoped to this call — it fires on every function return
    # afterward (including the caller's), crashing on the next invocation
    # with "key: unbound variable" once $key is out of scope.
    local key
    key="$(mktemp)"
    curl -fsSL "$key_url" -o "$key"

    if ! gpg --show-keys --with-colons "$key" \
        | awk -F: '/^fpr:/ { print $10 }' \
        | grep -qx "$expected_fpr"; then
        error "GPG key fingerprint mismatch for ${list_file} — refusing to trust it."
        error "Expected ${expected_fpr}. Got:"
        gpg --show-keys --with-colons "$key" | awk -F: '/^fpr:/ { print "  " $10 }'
        rm -f "$key"
        return 1
    fi

    sudo gpg --dearmor -o "$keyring_path" < "$key"
    echo "$repo_line" | sudo tee "$list_file" > /dev/null
    rm -f "$key"
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
    # A plain `command -v firefox` guard (like every sibling function below)
    # would be WRONG here: Ubuntu's transitional stub also provides
    # /usr/bin/firefox, so it would look "already installed" and this would
    # never converge to Mozilla's real build. Distinguish by dpkg version
    # instead — the stub fakes a `1:` epoch (see the --allow-downgrades
    # comment below); Mozilla's real packages never have one.
    local installed_version
    installed_version="$(dpkg-query -W -f='${Version}' firefox 2>/dev/null || true)"
    if [[ -n "$installed_version" && "$installed_version" != 1:* ]]; then
        warn "Already installed: firefox ($installed_version)"
        return 0
    fi

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
    # Ubuntu's transitional "firefox" stub (which just installs the Snap) uses
    # a fake `1:` epoch specifically to always out-rank real competing repos in
    # version comparisons. Pin-Priority above only controls candidate
    # selection for a fresh install, not apt's downgrade-protection check
    # against an already-installed higher-epoch package — --allow-downgrades
    # is required to actually replace it with Mozilla's real build.
    sudo apt-get install -y --allow-downgrades firefox && success "Installed: firefox" || error "Failed to install: firefox — continuing..."
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
    curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL \
        https://release.gitkraken.com/linux/gitkraken-amd64.deb -o "$deb"
    sudo apt-get install -y "$deb" && success "Installed: gitkraken" || error "Failed to install: gitkraken — continuing..."
    rm -f "$deb"
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
# JetBrains Toolbox — NO apt/dpkg or Snap path exists (the only Snap under
# this name was an unofficial, non-functional third-party repackaging by
# "jnsougata" — do not reintroduce it). JetBrains' own releases API resolves
# the current stable Linux tarball AND its sha256 checksum, verified below
# before extraction — a real integrity check, unlike install_zed/
# install-omp.sh's curl installers, which only get HTTPS-transport trust.
# https://www.jetbrains.com/help/toolbox-app/installation.html
#
# No silent-install flag exists on Linux (JetBrains' own docs: "For Linux
# and macOS, a silent installation is not possible") — this replicates the
# manual tar.gz + first-launch flow: extract, symlink onto PATH, install the
# bundled .desktop file. Toolbox still self-configures its autostart entry,
# proper icon, and jetbrains:// URI handler on first real launch — this
# script only gets it onto the app menu and PATH, matching Zed's install_zed
# bar (gets the binary running, doesn't fully replicate every first-run step).
# ------------------------------------------
JETBRAINS_TOOLBOX_DIR="$HOME/Applications/jetbrains-toolbox"

install_jetbrains_toolbox() {
    if [[ -x "$JETBRAINS_TOOLBOX_DIR/bin/jetbrains-toolbox" ]]; then
        warn "Already installed: jetbrains-toolbox"
        return 0
    fi

    local release_json download_url checksum_url tmpdir tarball checksum_file expected_sha actual_sha
    release_json="$(curl -fsSL 'https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release')"
    download_url="$(printf '%s' "$release_json" | jq -r '.TBA[0].downloads.linux.link')"
    checksum_url="$(printf '%s' "$release_json" | jq -r '.TBA[0].downloads.linux.checksumLink')"

    if [[ -z "$download_url" || "$download_url" == "null" ]]; then
        error "Could not resolve JetBrains Toolbox download URL — continuing."
        return 1
    fi

    tmpdir="$(mktemp -d)"
    tarball="$tmpdir/toolbox.tar.gz"
    checksum_file="$tmpdir/toolbox.tar.gz.sha256"
    curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL -o "$tarball" "$download_url"
    curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL -o "$checksum_file" "$checksum_url"

    expected_sha="$(awk '{print $1}' "$checksum_file")"
    actual_sha="$(sha256sum "$tarball" | awk '{print $1}')"
    if [[ "$actual_sha" != "$expected_sha" ]]; then
        error "JetBrains Toolbox checksum mismatch — refusing to install."
        error "Expected ${expected_sha}"
        error "Actual   ${actual_sha}"
        rm -rf "$tmpdir"
        return 1
    fi

    mkdir -p "$JETBRAINS_TOOLBOX_DIR" "$HOME/.local/bin" "$HOME/.local/share/applications"
    tar -xzf "$tarball" -C "$JETBRAINS_TOOLBOX_DIR" --strip-components=1
    rm -rf "$tmpdir"

    ln -sf "$JETBRAINS_TOOLBOX_DIR/bin/jetbrains-toolbox" "$HOME/.local/bin/jetbrains-toolbox"
    sed "s|^Exec=jetbrains-toolbox|Exec=$JETBRAINS_TOOLBOX_DIR/bin/jetbrains-toolbox|" \
        "$JETBRAINS_TOOLBOX_DIR/bin/jetbrains-toolbox.desktop" \
        > "$HOME/.local/share/applications/jetbrains-toolbox.desktop"

    success "Installed: jetbrains-toolbox ($JETBRAINS_TOOLBOX_DIR)"
    warn "Launch it once from your app menu — Toolbox sets up its own autostart entry, icon, and jetbrains:// URI handler on first run."
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
# Postman — official download, no apt/dpkg/Snap involvement. Postman's own
# docs recommend Snap ("bundles all needed libraries") and don't publish a
# checksum for this tarball, so this is HTTPS-transport-only trust — same
# tier as install_zed/install-omp.sh's curl installers, weaker than
# install_jetbrains_toolbox's checksummed download.
# https://learning.postman.com/docs/getting-started/installation/install-app
# ------------------------------------------
# The tarball's top-level dir is literally "Postman" (capital, no version
# suffix) — POSTMAN_DIR matches that casing exactly rather than renaming, so
# a plain `tar -xzf -C "$HOME/Applications"` (no --strip-components needed)
# lands exactly where this points.
POSTMAN_DIR="$HOME/Applications/Postman"

install_postman() {
    if [[ -x "$POSTMAN_DIR/Postman" ]]; then
        warn "Already installed: postman"
        return 0
    fi

    local tarball tmpdir
    tmpdir="$(mktemp -d)"
    tarball="$tmpdir/postman.tar.gz"
    curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL \
        -o "$tarball" "https://dl.pstmn.io/download/latest/linux64"

    mkdir -p "$HOME/Applications" "$HOME/.local/bin" "$HOME/.local/share/applications"
    rm -rf "$POSTMAN_DIR"
    tar -xzf "$tarball" -C "$HOME/Applications"
    rm -rf "$tmpdir"

    ln -sf "$POSTMAN_DIR/Postman" "$HOME/.local/bin/postman"
    cat > "$HOME/.local/share/applications/postman.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Postman
Exec=$POSTMAN_DIR/Postman %U
Icon=$POSTMAN_DIR/app/resources/app/assets/icon.png
Categories=Development;
Terminal=false
StartupWMClass=Postman
EOF

    success "Installed: postman ($POSTMAN_DIR)"
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
    curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL \
        https://zed.dev/install.sh -o "$zed_installer"
    sh "$zed_installer" && success "Installed: zed" || error "Failed to install: zed — continuing..."
    rm -f "$zed_installer"
}

# --------------------------------------------------
# Main
# --------------------------------------------------
main() {
    if [[ "$OS" != "debian" ]]; then
        warn "install-gui-ubuntu.sh is Ubuntu-only — these apps are already Homebrew casks via install-gui-cask.sh on macOS."
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
    install_jetbrains_toolbox
    install_ngrok
    install_postman
    install_vscode

    success "GUI apt app installation complete."
}

main "$@"
