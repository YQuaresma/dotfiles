#!/usr/bin/env bash
# Installs every GUI app for the current OS, dispatching to the package-manager
# scripts that actually do the work: install-gui-cask.sh (Homebrew, macOS),
# install-gui-snap.sh + install-gui-apt.sh (Ubuntu — complementary, not
# overlapping: apt covers apps with an official repo, Snap covers the rest).
# Each of those already self-detects OS and no-ops on the wrong one, so
# running them individually is equally safe; this just saves knowing which
# ones apply on which OS.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

if [[ "$OS" == "macos" ]]; then
    bash "${SCRIPT_DIR}/install-gui-cask.sh"

elif [[ "$OS" == "debian" ]]; then
    bash "${SCRIPT_DIR}/install-gui-snap.sh"
    bash "${SCRIPT_DIR}/install-gui-apt.sh"

else
    error "Unsupported OS: ${OS}"; exit 1
fi
