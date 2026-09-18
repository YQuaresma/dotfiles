#!/usr/bin/env bash
# Single source of truth for the GUI app lists, sourced by both
# install-apps-gui.sh and remove-apps-gui.sh.
#
# It lives in one file on purpose: the two scripts previously kept separate
# lists that had drifted apart, so `remove-apps-gui.sh` uninstalled apps the
# installer never installed (clocker, three Nerd Fonts) while leaving behind
# ones it did install (1password, balenaetcher, meetingbar, jetbrains-toolbox).
# An "undo" script that removes things you installed by hand is worse than one
# that does nothing. Edit here and both sides stay in step.
#
# GUI_SNAPS entries are "<package> [install flags]"; the flags are used only by
# the installer. Use snap_pkg_name() to get the bare package name.

# macOS — Homebrew casks
GUI_CASKS=(
  "1password"
  "balenaetcher"
  "claude"
  "drawio"
  "firefox"
  "gitkraken"
  "google-chrome"
  "jetbrains-toolbox"
  "meetingbar"
  "meld"
  "ngrok"
  "notion"
  "postman"
  "rectangle"
  "sourcetree"
  "sublime-text"
  "visual-studio-code"
  "whatsapp"
)

# Ubuntu — snaps. `--classic` and `--devmode` disable snap confinement, so each
# one is an explicit decision, not a default.
GUI_SNAPS=(
  "1password"
  "code --classic"
  "drawio"
  "firefox"
  "gitkraken --classic"
  "jetbrains-toolbox --beta"
  "ngrok"
  "notion-desktop"
  "postman"
  "sublime-text --classic"
)

# snap_pkg_name "<entry>" -> bare package name (strips install flags)
snap_pkg_name() { printf '%s' "${1%% *}"; }

# snap_pkg_flags "<entry>" -> install flags, or empty when there are none
snap_pkg_flags() {
    local entry="$1" flags="${1#* }"
    [[ "$flags" == "$entry" ]] && flags=""
    printf '%s' "$flags"
}
