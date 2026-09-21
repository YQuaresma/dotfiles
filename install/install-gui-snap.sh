#!/usr/bin/env bash
# Installs GUI apps via Snap. Ubuntu only — split out of the old combined
# script so each package manager has its own; see install-gui-cask.sh
# (Homebrew casks, macOS) and install-gui-apt.sh (official apt repos,
# Ubuntu). GUI_SNAPS covers only the apps with no official apt path.
#
# GUI_SNAPS must stay in sync with remove-gui-snap.sh's copy — an "undo"
# script that removes things it never installed, or leaves behind things it
# did, is worse than one that does nothing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

if [[ "$OS" != "debian" ]]; then
    warn "install-gui-snap.sh is Ubuntu-only — see install-gui-cask.sh on macOS."
    exit 0
fi

# Entries are "<package> [install flags]"; `--classic`/`--devmode` disable
# snap confinement, so each one is an explicit decision, not a default.
GUI_SNAPS=(
    "drawio"
    "jetbrains-toolbox --beta"
    "notion-desktop"
    "postman"
)

# snap_pkg_name "<entry>" -> bare package name (strips install flags)
snap_pkg_name() { printf '%s' "${1%% *}"; }

# snap_pkg_flags "<entry>" -> install flags, or empty when there are none
snap_pkg_flags() {
    local entry="$1" flags="${1#* }"
    [[ "$flags" == "$entry" ]] && flags=""
    printf '%s' "$flags"
}

echo "--------------------------------"
cog_msg "Installing Snap applications..."
echo "--------------------------------"

for entry in "${GUI_SNAPS[@]}"; do
    pkg="$(snap_pkg_name "$entry")"
    flags="$(snap_pkg_flags "$entry")"
    if snap list "$pkg" &>/dev/null; then
        warn "Already installed: $pkg"
    else
        # shellcheck disable=SC2086
        sudo snap install $flags "$pkg" && success "Installed: $pkg" || error "Failed to install: $pkg — continuing..."
    fi
done

success "GUI Snap app installation complete."
