#!/usr/bin/env bash
# Removes every GUI app for the current OS, dispatching to the package-manager
# scripts that actually do the work: remove-gui-macos.sh (Homebrew, macOS),
# remove-gui-ubuntu.sh (Ubuntu). See install-gui-apps.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

if [[ "$OS" == "macos" ]]; then
    bash "${SCRIPT_DIR}/remove-gui-macos.sh"

elif [[ "$OS" == "debian" ]]; then
    bash "${SCRIPT_DIR}/remove-gui-ubuntu.sh"

else
    error "Unsupported OS: ${OS}"; exit 1
fi
