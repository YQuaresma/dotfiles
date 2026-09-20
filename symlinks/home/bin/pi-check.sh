#!/usr/bin/env bash
# Usage: ./pi-check.sh [ip1] [ip2] ...
# Targets come from the arguments, or from the PI_IPS env var (comma-separated).
# There is no built-in default: a LAN address is site-specific and does not
# belong in a published repo. Put your own in ~/.config/pi-check/config.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/functions.sh"
OS="$(detect_os)"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── Config ────────────────────────────────────────────────────────────────────
# Optional local-only config, sourced if present. Keep site-specific values
# (PI_IPS, PI_USER, PI_CHECK_DOMAINS) here rather than in this tracked script:
#   PI_IPS=<pi-ip>,<pi-ip>
#   PI_USER=pi
#   PI_CHECK_DOMAINS=doubleclick.net,ads.example.net
PI_CHECK_CONFIG="${PI_CHECK_CONFIG:-$HOME/.config/pi-check/config}"
# shellcheck source=/dev/null
[[ -f "$PI_CHECK_CONFIG" ]] && source "$PI_CHECK_CONFIG"

IFS=',' read -ra DEFAULT_PI_IPS <<< "${PI_IPS:-}"
SSH_USER="${PI_USER:-pi}"
SSH_KEY="$HOME/.ssh/pihole"
# accept-new, never "no": StrictHostKeyChecking=no accepts a *changed* host key
# too, so any LAN-level MITM taking over the Pi's address gets a session that
# this script hands the private key to and then drives with sudo commands.
# Array, not a string — a $HOME containing a space would split "-i <path>".
SSH_OPTS=(-i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -o BatchMode=yes)

# Known DNS block-page IPs (Pi-hole, Cisco Umbrella, OpenDNS, CleanBrowsing)
BLOCK_PAGE_IPS=(
    "0.0.0.0"
    "146.112.61.106"   # Cisco Umbrella
    "146.112.61.107"   # Cisco Umbrella
    "208.69.38.205"    # OpenDNS
    "208.69.39.205"    # OpenDNS
    "67.215.65.132"    # OpenDNS
    "185.228.168.168"  # CleanBrowsing
    "185.228.169.168"  # CleanBrowsing
)

# Domains used as the blocking probe. Default is a neutral ad/tracker domain
# present in every stock Pi-hole blocklist; override with PI_CHECK_DOMAINS
# (comma-separated) in the local config if you test a different category.
IFS=',' read -ra TEST_DOMAINS <<< "${PI_CHECK_DOMAINS:-doubleclick.net,google-analytics.com,pornhub.com,xvideos.com,xnxx.com,xhamster.com,youporn.com,redtube.com,deviantart.com}"

# ── Helpers ───────────────────────────────────────────────────────────────────
warn()   { echo -e "${YELLOW}$*${NC}"; }
label()  { printf "${CYAN}  %-10s : %s${NC}\n" "$1" "$2"; }
blocked() { echo -e "  ✅ BLOCKED    $*"; }
fail()   { echo -e "${RED}  NOT BLOCKED  $*${NC}"; }
div()    { echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

is_blocked() {
    local resolved="$1"
    [[ -z "$resolved" ]] && return 0
    for block_ip in "${BLOCK_PAGE_IPS[@]}"; do
        [[ "$resolved" == "$block_ip" ]] && return 0
    done
    return 1
}

# ── Gather info from local machine ────────────────────────────────────────────
local_info() {
    local model os_info
    if [[ "$OS" == "macos" ]]; then
        model=$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Name/{print $2}' | xargs)
        os_info="$(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"
    else
        model=$(uname -m)
        os_info=$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME}" || uname -sr)
    fi
    echo "${model:-$(uname -m)}"
    echo "${os_info}"
    echo ""   # no Pi-hole on local machine
}

# ── Gather info from a Pi via SSH ─────────────────────────────────────────────
pi_info() {
    local ip="$1"
    ssh "${SSH_OPTS[@]}" "${SSH_USER}@${ip}" bash -s <<'REMOTE' 2>/dev/null || printf 'unknown\nunknown\nunknown'
model=$(cat /sys/firmware/devicetree/base/model 2>/dev/null | tr -d '\0' || grep Model /proc/cpuinfo | cut -d: -f2 | xargs)
os=$(. /etc/os-release && echo "${PRETTY_NAME}")
core=$(sudo pihole version 2>/dev/null | grep -i "Core version" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
ftl=$(sudo pihole version 2>/dev/null | grep -i "FTL version" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
printf '%s\n%s\nCore %s  FTL %s' "${model:-unknown}" "${os}" "${core:-N/A}" "${ftl:-N/A}"
REMOTE
}

# ── Test one resolver ─────────────────────────────────────────────────────────
test_resolver() {
    local resolver="$1"   # IP or "local"
    local target="$2"
    local model_line="$3"
    local os_line="$4"
    local pihole_line="$5"
    local passed=0 failed=0

    echo ""
    div
    label "Host"       "${target}"
    label "Model"      "${model_line}"
    label "OS version" "${os_line}"
    [[ -n "$pihole_line" ]] && label "Pi-hole" "${pihole_line}"
    div

    for domain in "${TEST_DOMAINS[@]}"; do
        if [[ "$resolver" == "local" ]]; then
            resolved=$(dig +short "$domain" A 2>/dev/null | grep -E '^[0-9]+\.' | head -1 || true)
        else
            resolved=$(dig +short "@${resolver}" "$domain" A 2>/dev/null | grep -E '^[0-9]+\.' | head -1 || true)
        fi

        if is_blocked "$resolved"; then
            blocked "${domain}  →  ${resolved:-NXDOMAIN}"
            passed=$((passed + 1))
        else
            fail "${domain}  →  ${resolved}"
            failed=$((failed + 1))
        fi
    done

    echo ""
    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}  ✓ ${target}: all ${passed}/${#TEST_DOMAINS[@]} domains blocked.${NC}"
    else
        warn "  ! ${target}: ${failed}/${#TEST_DOMAINS[@]} domains NOT blocked."
    fi
}

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
    echo ""
    echo -e "${BOLD}Usage:${NC} $(basename "$0") [OPTIONS] [ip1] [ip2] ..."
    echo ""
    echo "  Test Pi-hole DNS blocking against a set of probe domains."
    echo "  Always checks the local machine's system DNS first, then each Pi."
    echo ""
    echo -e "${BOLD}Arguments:${NC}"
    echo "  [ip1] [ip2] ...   Pi-hole IP addresses to test"
    echo "                    Falls back to PI_IPS from the environment or from"
    echo "                    ${PI_CHECK_CONFIG/#"$HOME"/\~}"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo "  -h, --help        Show this help message and exit"
    echo ""
    echo -e "${BOLD}Environment variables:${NC}"
    echo "  PI_IPS            Comma-separated list of default Pi IPs"
    echo "                    e.g. PI_IPS=<pi-ip>,<pi-ip> $(basename "$0")"
    echo "  PI_USER           SSH user (default: pi)"
    echo "  PI_CHECK_DOMAINS  Comma-separated probe domains"
    echo "                    (default: doubleclick.net,google-analytics.com)"
    echo "  PI_CHECK_CONFIG   Local config file to source"
    echo "                    (default: ~/.config/pi-check/config)"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  $(basename "$0") <pi-ip> <pi-ip>"
    echo "  PI_IPS=<pi-ip> $(basename "$0")"
    echo "  PI_USER=admin $(basename "$0") <pi-ip>"
    echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ $# -gt 0 ]]; then
    TARGET_IPS=("$@")
elif [[ ${#DEFAULT_PI_IPS[@]} -gt 0 && -n "${DEFAULT_PI_IPS[0]}" ]]; then
    TARGET_IPS=("${DEFAULT_PI_IPS[@]}")
else
    error "No Pi IPs given. Pass them as arguments, set PI_IPS, or create ${PI_CHECK_CONFIG/#"$HOME"/\~}."
    usage
    exit 1
fi

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       Pi-hole Blocking Test          ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"

# Local machine
local_sys=$(local_info)
local_model=$(echo "$local_sys" | sed -n '1p')
local_os=$(echo "$local_sys"    | sed -n '2p')
test_resolver "local" "This machine (system DNS)" "$local_model" "$local_os" ""

# Each Pi
for ip in "${TARGET_IPS[@]}"; do
    if dig +short +time=3 "@${ip}" "pi.hole" &>/dev/null; then
        pi_sys=$(pi_info "$ip")
        pi_model=$(echo "$pi_sys"  | sed -n '1p')
        pi_os=$(echo "$pi_sys"     | sed -n '2p')
        pi_pihole=$(echo "$pi_sys" | sed -n '3p')
        test_resolver "$ip" "Pi-hole @ ${ip}" "$pi_model" "$pi_os" "$pi_pihole"
    else
        echo ""
        warn "  ! Cannot reach ${ip} as a DNS resolver — is it online?"
    fi
done

echo ""
div
echo -e "${CYAN}  Done.${NC}"
