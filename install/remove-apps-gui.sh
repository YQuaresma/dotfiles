#!/usr/bin/env bash
# Removes GUI apps installed by install-apps-gui.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
# Same list the installer uses, so this removes exactly what was installed —
# no more (it used to uninstall apps the installer never touched) and no less.
# shellcheck source=install/apps-gui.list.sh
source "${SCRIPT_DIR}/apps-gui.list.sh"
OS="$(detect_os)"

echo "--------------------------------"
cog_msg "Removing GUI apps..."
echo "--------------------------------"

if [[ "$OS" == "macos" ]]; then
    for pkg in "${GUI_CASKS[@]}"; do
        if brew list --cask "$pkg" &>/dev/null; then
            brew uninstall --cask "$pkg" && success "Removed: $pkg" || error "Failed to remove: $pkg — continuing..."
        else
            warn "Not installed: $pkg"
        fi
    done

elif [[ "$OS" == "debian" ]]; then
    for entry in "${GUI_SNAPS[@]}"; do
        pkg="$(snap_pkg_name "$entry")"
        if snap list "$pkg" &>/dev/null 2>&1; then
            sudo snap remove "$pkg" && success "Removed: $pkg" || error "Failed to remove: $pkg — continuing..."
        else
            warn "Not installed: $pkg"
        fi
    done

else
    error "Unsupported OS: ${OS}"; exit 1
fi

success "GUI app removal complete."
