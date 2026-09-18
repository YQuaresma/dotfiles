#!/usr/bin/env bash
# Usage: ./pi-update.sh <ip_address>
#   e.g. ./pi-update.sh <pi-ip>
# Override SSH user: PI_USER=myuser ./pi-update.sh <ip>

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; ORANGE='\033[38;5;208m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
    echo ""
    echo -e "${BOLD}Usage:${NC} $(basename "$0") [OPTIONS] <ip_address>"
    echo ""
    echo "  Update a Pi-hole: runs apt update/upgrade/autoremove and pihole -up,"
    echo "  then reboots and waits for the Pi to come back online."
    echo ""
    echo -e "${BOLD}Arguments:${NC}"
    echo "  <ip_address>      IP address of the Pi-hole to update (required)"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo "  -h, --help        Show this help message and exit"
    echo ""
    echo -e "${BOLD}Environment variables:${NC}"
    echo "  PI_USER           SSH user (default: pi)"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  $(basename "$0") <pi-ip>"
    echo "  PI_USER=admin $(basename "$0") <pi-ip>"
    echo ""
}

# ── Args ──────────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

PI_IP="$1"
SSH_USER="${PI_USER:-pi}"
SSH_KEY="$HOME/.ssh/pihole"
# accept-new, never "no": StrictHostKeyChecking=no also accepts a *changed* host
# key, so a LAN-level MITM on the Pi's address would be handed this private key
# and then driven through the sudo apt/pihole/shutdown steps below.
# Array, not a string — a $HOME containing a space would split "-i <path>".
SSH_OPTS=(-i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes)
REBOOT_WAIT_SECS=120   # max seconds to wait for the Pi to come back online
POLL_INTERVAL=5

# ── Helpers ───────────────────────────────────────────────────────────────────
log()     { echo -e "${ORANGE}  $*${NC}"; }
success() { echo -e "${GREEN}  ✓ $*${NC}"; }
warn()    { echo -e "${YELLOW}  ! $*${NC}"; }
error()   { echo -e "${RED}  ✗ $*${NC}"; }
label() { printf "${CYAN}  %-10s : %s${NC}\n" "$1" "$2"; }
div()   { echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
step()  {
    echo ""
    echo -e "${BOLD}──────────────────────────────────────${NC}"
    echo -e "${BOLD}  $*${NC}"
    echo -e "${BOLD}──────────────────────────────────────${NC}"
}

ssh_pi() { ssh "${SSH_OPTS[@]}" "${SSH_USER}@${PI_IP}" "$@"; }

# ── Pre-flight ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║        Pi-hole Updater               ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"
if ! ssh_pi "echo connected" &>/dev/null; then
    error "Cannot reach ${PI_IP} — is it online and is the SSH key installed?"
    exit 1
fi

pi_sys=$(ssh_pi bash -s <<'REMOTE' 2>/dev/null || printf 'unknown\nunknown\nunknown'
model=$(cat /sys/firmware/devicetree/base/model 2>/dev/null | tr -d '\0' || grep Model /proc/cpuinfo | cut -d: -f2 | xargs)
os=$(. /etc/os-release && echo "${PRETTY_NAME}")
core=$(sudo pihole version 2>/dev/null | grep -i "Core version" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
ftl=$(sudo pihole version 2>/dev/null | grep -i "FTL version" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
printf '%s\n%s\nCore %s  FTL %s' "${model:-unknown}" "${os}" "${core:-N/A}" "${ftl:-N/A}"
REMOTE
)
pi_model=$(echo "$pi_sys"  | sed -n '1p')
pi_os=$(echo "$pi_sys"     | sed -n '2p')
pi_pihole=$(echo "$pi_sys" | sed -n '3p')

echo ""
div
label "Host"       "Pi-hole @ ${PI_IP}"
label "Model"      "${pi_model}"
label "OS version" "${pi_os}"
label "Pi-hole"    "${pi_pihole}"
div

# ── OS update ─────────────────────────────────────────────────────────────────
step "[1/4] apt update — refreshing package lists"
ssh_pi "sudo apt-get update"

step "[2/4] apt upgrade — upgrading packages"
ssh_pi "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    -o Dpkg::Options::='--force-confdef' \
    -o Dpkg::Options::='--force-confold'"

step "[3/4] apt autoremove — removing unused packages"
ssh_pi "sudo apt-get autoremove -y"

# ── Pi-hole update ────────────────────────────────────────────────────────────
step "[4/4] Pi-hole update"
ssh_pi "sudo pihole -up"

# ── Reboot ────────────────────────────────────────────────────────────────────
echo ""
log "All steps complete — rebooting ${PI_IP}..."
ssh_pi "sudo shutdown -r +0 'Pi-hole maintenance reboot'" || true

# ── Wait for Pi to come back ──────────────────────────────────────────────────
echo ""
log "Waiting for ${PI_IP} to come back online (max ${REBOOT_WAIT_SECS}s)..."
START=$(date +%s)
# Give it a moment to actually go down before we start polling
sleep 10
while true; do
    ELAPSED=$(( $(date +%s) - START ))
    if [[ $ELAPSED -ge $REBOOT_WAIT_SECS ]]; then
        error "${PI_IP} did not come back online within ${REBOOT_WAIT_SECS}s."
        exit 1
    fi
    if ssh_pi "echo online" &>/dev/null; then
        break
    fi
    echo -ne "\r  ${YELLOW}Waiting... ${ELAPSED}s elapsed${NC}   "
    sleep $POLL_INTERVAL
done

echo ""
success "${PI_IP} is back online after ~$(( $(date +%s) - START ))s."
echo -e "  ✅ Update complete."
