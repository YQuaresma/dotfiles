#!/usr/bin/env bash
# Removes Azure Functions Core Tools installed by install-azure-functions.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

echo "--------------------------------"
cog_msg "Removing Azure Functions Core Tools..."
echo "--------------------------------"

if ! command -v func &>/dev/null; then
    warn "Not installed: Azure Functions Core Tools"
    exit 0
fi

if [[ "$OS" == "macos" ]]; then
    brew uninstall azure-functions-core-tools@4 || true
    brew untap azure/functions || true

elif [[ "$OS" == "debian" ]]; then
    sudo apt-get remove -y azure-functions-core-tools-4
    sudo apt-get autoremove -y
    sudo rm -f /etc/apt/sources.list.d/dotnetdev.list

else
    error "Unsupported OS: ${OS}"; exit 1
fi

success "Azure Functions Core Tools removed."
