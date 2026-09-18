#!/usr/bin/env bash

# -----------------------------
# Color & Icon Definitions
# -----------------------------
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BOLD="\033[1m"
RESET="\033[0m"

ICON_CHECK="✅ "
ICON_WARN="⚠️ "
ICON_ERROR="❌ "
ICON_INFO="💡 "
ICON_COG="⚙️ "
ICON_START="▶️  "
ICON_TICK="  ✔"
# -----------------------------
# Logging Functions
# -----------------------------
arrow()     { echo -e "${ICON_START}${YELLOW}$*${RESET}"; }
info()      { echo -e "${YELLOW}${ICON_INFO} $*${RESET}"; }
success()   { echo -e "${GREEN}${ICON_CHECK} $*${RESET}"; }
warn()      { echo -e "${YELLOW}${ICON_WARN} $*${RESET}"; }
error()     { echo -e "${RED}${ICON_ERROR} $*${RESET}"; }
cog_msg()   { echo -e "${BOLD}${ICON_COG} $*${RESET}"; }
# banner "message" — prints a section header: separator, cog_msg, separator,
# with each separator's dash count sized to the message length + 5 extra.
banner() {
    local msg="$1" sep
    sep="$(printf -- '-%.0s' $(seq 1 $((${#msg} + 5))))"
    echo "$sep"
    cog_msg "$msg"
    echo "$sep"
}
tick()      { echo -e "${ICON_TICK} $*${RESET}"; }
highlight() { echo -e "${YELLOW}$*${RESET}"; }
bold()      { echo -e "${BOLD} $*${RESET}"; }

# -------------------------------
# Function: confirm
# Generic Y/N prompt for sections
# -------------------------------
confirm() {
    while true; do
        read -r -p "${ICON_START}$1 [y/N]: " response
        case "$response" in
            [yY][eE][sS]|[yY]) return 0 ;;
            [nN]|"") return 1 ;;
            *) warn " Please answer with (Y or N)"
               echo
               ;;
        esac
    done
}

# -------------------------------------------------------------
# Function: Remove broken apt hooks that reference missing scripts
# Call before any apt-get operation on Ubuntu to avoid hook errors
# -------------------------------------------------------------
fix_apt_hooks() {
    if [[ -f /etc/apt/apt.conf.d/99-ubuntu-virt.conf ]] && [[ ! -f /usr/bin/apt_hook_ubuntu_virt ]]; then
        warn "Removing broken apt hook: 99-ubuntu-virt.conf (hook script missing)"
        sudo rm -f /etc/apt/apt.conf.d/99-ubuntu-virt.conf
    fi
}

# -------------------------------
# Function: Detect OS
# -------------------------------
detect_os() {
    local os_type distro_id
    os_type="$(uname -s)"
    case "${os_type}" in
        Darwin)
            echo "macos"
            ;;
        Linux)
            local distro_id distro_like
            . /etc/os-release 2>/dev/null || true
            distro_id="${ID:-unknown}"
            distro_like="${ID_LIKE:-}"
            if [[ "${distro_id}" != "debian" && "${distro_like}" != *"debian"* ]]; then
                echo "Unsupported Linux distro: ${distro_id}" >&2; exit 1
            fi
            echo "debian"
            ;;
        *)
            echo "Unsupported OS: ${os_type}" >&2; exit 1
            ;;
    esac
}