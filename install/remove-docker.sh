#!/usr/bin/env bash
# Removes Docker Engine and Docker Desktop installed by install-docker.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

echo "--------------------------------"
cog_msg "Removing Docker..."
echo "--------------------------------"

if [[ "$OS" == "macos" ]]; then
    if [[ -d "/Applications/Docker.app" ]]; then
        brew uninstall --cask docker
        success "Docker Desktop removed."
    else
        warn "Not installed: Docker Desktop"
    fi

elif [[ "$OS" == "debian" ]]; then
    if command -v docker &>/dev/null; then
        sudo apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo apt-get autoremove -y
        sudo rm -f /etc/apt/sources.list.d/docker.sources
        sudo rm -f /etc/apt/keyrings/docker.asc
        sudo gpasswd -d "$USER" docker 2>/dev/null || true
        success "Docker Engine removed."
    else
        warn "Not installed: Docker Engine"
    fi

    if dpkg -l docker-desktop 2>/dev/null | grep -q "^ii"; then
        sudo apt-get remove -y docker-desktop
        sudo apt-get autoremove -y
        systemctl --user disable docker-desktop 2>/dev/null || true
        success "Docker Desktop removed."
    else
        warn "Not installed: Docker Desktop"
    fi

else
    error "Unsupported OS: ${OS}"; exit 1
fi
