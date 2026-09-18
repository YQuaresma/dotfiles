#!/usr/bin/env bash
# Installs Docker.
# macOS: Docker Desktop only, via Homebrew cask (bundles its own engine).
# Ubuntu: Docker Engine AND Docker Desktop, independently — Engine via Docker's
# official APT repo, Desktop via the standalone .deb from desktop.docker.com.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

# ------------------------------------------
# Detection helpers
# ------------------------------------------
engine_installed() { command -v docker &>/dev/null; }

desktop_installed() {
    if [[ "$OS" == "macos" ]]; then
        [[ -d "/Applications/Docker.app" ]]
    else
        dpkg -l docker-desktop 2>/dev/null | grep -q "^ii"
    fi
}

desktop_version() {
    if [[ "$OS" == "macos" ]]; then
        defaults read /Applications/Docker.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo "unknown"
    else
        dpkg -l docker-desktop 2>/dev/null | awk '/^ii/{print $3}'
    fi
}

# ------------------------------------------
# macOS — Docker Desktop only (bundles its own engine)
# ------------------------------------------
install_macos() {
    if desktop_installed; then
        warn "Already installed: Docker Desktop ($(desktop_version))"
        engine_installed && warn "Already installed: Docker Engine ($(docker --version))"
        exit 0
    fi

    brew install --cask docker
    success "Docker Desktop installed."
}

# ------------------------------------------
# Ubuntu — Engine and Desktop, tracked and installed independently
# ------------------------------------------
# Docker's package-signing key. Pinned as a full fingerprint: an APT trust
# anchor is equivalent to root code execution for every future apt install, so
# fetch-and-trust without verification is not good enough.
DOCKER_GPG_FPR="9DC858229FC7DD38854AE2D88D81803C0EBFCD88"

add_docker_apt_repo() {
    [[ -f /etc/apt/sources.list.d/docker.sources ]] && return 0

    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings

    # Download as the unprivileged user and verify before it becomes a trust
    # anchor — never `sudo curl`, which would parse attacker-reachable TLS and
    # HTTP input as root.
    local key
    key="$(mktemp)"
    trap 'rm -f "$key"' RETURN
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o "$key"

    if ! gpg --show-keys --with-colons "$key" \
        | awk -F: '/^fpr:/ { print $10 }' \
        | grep -qx "$DOCKER_GPG_FPR"; then
        error "Docker GPG key fingerprint mismatch — refusing to trust it."
        error "Expected ${DOCKER_GPG_FPR}. Got:"
        gpg --show-keys --with-colons "$key" | awk -F: '/^fpr:/ { print "  " $10 }'
        return 1
    fi

    sudo install -m 0644 "$key" /etc/apt/keyrings/docker.asc
    sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    sudo apt-get update
}

install_engine_debian() {
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$USER"
    success "Docker Engine installed."
    warn "Docker group membership requires logout/login to take effect."
}

install_desktop_debian() {
    local arch="$1" tmpdir deb
    # A private 0700 directory, not a fixed /tmp path: on a multi-user box a
    # local user can pre-create /tmp/docker-desktop.deb and swap its contents in
    # the window before `sudo apt-get install` reads it — a root-level local
    # privilege escalation, and apt does not verify signatures on a local .deb.
    #
    # `mktemp -d` + a fixed name inside it, rather than `mktemp -t foo.XXXXXX.deb`:
    # apt needs the .deb extension, but GNU mktemp's `-t` is deprecated and its
    # handling of a suffix after the Xs varies by coreutils version, while the
    # directory form behaves identically on GNU and BSD.
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' RETURN
    deb="${tmpdir}/docker-desktop-${arch}.deb"
    curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL -o "$deb" \
        "https://desktop.docker.com/linux/main/${arch}/docker-desktop-${arch}.deb"

    # Docker publishes no stable checksum URL for the "main" channel, so this
    # cannot be verified automatically. apt does not check signatures on a local
    # .deb and its maintainer scripts run as root, which leaves TLS as the only
    # control. Set DOCKER_DESKTOP_SHA256 (from the release notes) to close that.
    if [[ -n "${DOCKER_DESKTOP_SHA256:-}" ]]; then
        local actual
        actual="$(sha256sum "$deb" | awk '{print $1}')"
        if [[ "$actual" != "$DOCKER_DESKTOP_SHA256" ]]; then
            error "Docker Desktop checksum mismatch — refusing to install."
            error "Expected ${DOCKER_DESKTOP_SHA256}"
            error "Actual   ${actual}"
            return 1
        fi
        success "Docker Desktop checksum verified."
    else
        warn "DOCKER_DESKTOP_SHA256 not set — installing an unverified .deb as root."
        warn "Pin it from https://docs.docker.com/desktop/release-notes/ to verify."
    fi

    sudo apt-get install -y "$deb"
    systemctl --user enable docker-desktop 2>/dev/null || true
    success "Docker Desktop installed."
}

install_debian() {
    if engine_installed; then
        warn "Already installed: Docker Engine ($(docker --version))"
    fi
    if desktop_installed; then
        warn "Already installed: Docker Desktop ($(desktop_version))"
    fi
    if engine_installed && desktop_installed; then
        exit 0
    fi

    export DEBIAN_FRONTEND=noninteractive

    # Clear the stale apt hook that blocks installation on some Ubuntu versions.
    # Removing the dangling .conf is the fix; writing a fake `exit 0` binary into
    # /usr/bin would permanently no-op a distro-owned hook.
    fix_apt_hooks

    add_docker_apt_repo
    engine_installed || install_engine_debian
    desktop_installed || install_desktop_debian "$(dpkg --print-architecture)"
}

# --------------------------------------------------
# Main
# --------------------------------------------------
main() {
    echo "--------------------------------"
    cog_msg "Installing Docker..."
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
