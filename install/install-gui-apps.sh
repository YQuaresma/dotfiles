#!/usr/bin/env bash
# Installs every GUI app for the current OS, dispatching to the package-manager
# scripts that actually do the work: install-gui-macos.sh (Homebrew, macOS),
# install-gui-ubuntu.sh (apt repos/packages/tarballs/installers, Ubuntu).
# Each of those already self-detects OS and no-ops on the wrong one, so
# running them individually is equally safe; this just saves knowing which
# ones apply on which OS. There used to be a third, Snap-based script here
# (install-gui-snap.sh) for apps with no official install path — decommissioned
# once its last entry (Notion) was dropped: Notion has no official Linux app
# at all, so an unofficial Snap wasn't worth managing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

if [[ "$OS" == "macos" ]]; then
    bash "${SCRIPT_DIR}/install-gui-macos.sh"

elif [[ "$OS" == "debian" ]]; then
    bash "${SCRIPT_DIR}/install-gui-ubuntu.sh"

else
    error "Unsupported OS: ${OS}"; exit 1
fi
