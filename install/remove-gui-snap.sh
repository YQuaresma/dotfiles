#!/usr/bin/env bash
# Removes GUI apps installed by install-gui-snap.sh (Snap, Ubuntu only). See
# remove-gui-cask.sh (Homebrew casks, macOS) and remove-gui-apt.sh (apt,
# Ubuntu) for the other package managers.
#
# GUI_SNAPS must stay in sync with install-gui-snap.sh's copy — an "undo"
# script that removes things it never installed, or leaves behind things it
# did, is worse than one that does nothing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

if [[ "$OS" != "debian" ]]; then
    warn "remove-gui-snap.sh is Ubuntu-only — see remove-gui-cask.sh on macOS."
    exit 0
fi

GUI_SNAPS=(
    "drawio"
    "jetbrains-toolbox --beta"
    "notion-desktop"
    "postman"
)

# snap_pkg_name "<entry>" -> bare package name (strips install flags)
snap_pkg_name() { printf '%s' "${1%% *}"; }

echo "--------------------------------"
cog_msg "Removing GUI Snap apps..."
echo "--------------------------------"

for entry in "${GUI_SNAPS[@]}"; do
    pkg="$(snap_pkg_name "$entry")"
    if snap list "$pkg" &>/dev/null 2>&1; then
        sudo snap remove "$pkg" && success "Removed: $pkg" || error "Failed to remove: $pkg — continuing..."
    else
        warn "Not installed: $pkg"
    fi
done

success "GUI Snap app removal complete."
