#!/usr/bin/env bash
# Usage: ./pi-youtube-block.sh <on|off|status> [ip1] [ip2] ...
#
# Toggles a client-scoped YouTube block on one or more Pi-holes by flipping the
# enabled flag of a dedicated deny group (default "Block-Youtube"). The group's
# *client* membership (e.g. a single TV's MAC) is NOT managed here — set that
# once in the Pi-hole admin UI; this script only enables/disables the group and,
# on "on", (re)creates the deny domains and links them to it. When more than one
# Pi is targeted it also verifies the group's client scope is identical across
# them, so a device blocked on one Pi is not silently allowed by another.
#
# Targets come from the arguments, or from the PI_IPS env var (comma-separated),
# or from ~/.config/pi-check/config. There is no built-in default: a LAN address
# is site-specific and does not belong in a published repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/functions.sh"

# ── Config ────────────────────────────────────────────────────────────────────
# Optional local-only config, shared with pi-check.sh. Keep site-specific values
# here rather than in this tracked script:
#   PI_IPS=<pi-ip>,<pi-ip>
#   PI_USER=pi
#   PI_YT_GROUP=Block-Youtube
#   PI_YT_DOMAINS=youtube.com,www.youtube.com,m.youtube.com
PI_CHECK_CONFIG="${PI_CHECK_CONFIG:-$HOME/.config/pi-check/config}"
# shellcheck source=/dev/null
[[ -f "$PI_CHECK_CONFIG" ]] && source "$PI_CHECK_CONFIG"

IFS=',' read -ra DEFAULT_PI_IPS <<< "${PI_IPS:-}"
SSH_USER="${PI_USER:-pi}"
SSH_KEY="$HOME/.ssh/pihole"
GROUP="${PI_YT_GROUP:-Block-Youtube}"
DOMAINS="${PI_YT_DOMAINS:-youtube.com,www.youtube.com,m.youtube.com}"
# accept-new, never "no": StrictHostKeyChecking=no accepts a *changed* host key
# too. Array, not a string — a $HOME containing a space would split "-i <path>".
SSH_OPTS=(-i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -o BatchMode=yes)

usage() {
    cat <<EOF
Usage: $(basename "$0") <on|off|status> [ip ...]

  on      (re)create the deny domains, link them to the "${GROUP}" group,
          and enable that group
  off     disable the "${GROUP}" group (domains are kept for a later "on")
  status  show the group's enabled state, linked deny domains, and the
          clients it is scoped to

Targets: arguments, else \$PI_IPS, else ${PI_CHECK_CONFIG/#"$HOME"/\~}.
Override the group/domains with PI_YT_GROUP / PI_YT_DOMAINS (comma-separated).
With 2+ target Pis, every action also checks the group's client scope matches
across them and warns about any MAC/IP present on one Pi but missing on another.
EOF
}

# ── Remote worker ─────────────────────────────────────────────────────────────
# Runs on the Pi. Args: <action> <group> <comma-domains>
remote() {
    ssh "${SSH_OPTS[@]}" "${SSH_USER}@${1}" bash -s -- "$2" "$3" "$4" <<'REMOTE'
set -euo pipefail
action="$1"; group="$2"; domains="$3"
DB=/etc/pihole/gravity.db
q() { sudo pihole-FTL sqlite3 "$DB" "$1"; }
esc() { printf "%s" "$1" | sed "s/'/''/g"; }   # SQL single-quote escaping
g="$(esc "$group")"

gid="$(q "SELECT id FROM 'group' WHERE name='${g}';")"

case "$action" in
  on)
    if [[ -z "$gid" ]]; then
      q "INSERT INTO 'group' (enabled,name,description) VALUES (1,'${g}','Client-scoped YouTube block');"
      gid="$(q "SELECT id FROM 'group' WHERE name='${g}';")"
      echo "  created group '${group}' (id ${gid}) — set its client scope in the admin UI"
    fi
    IFS=',' read -ra doms <<< "$domains"
    for d in "${doms[@]}"; do
      [[ -z "$d" ]] && continue
      de="$(esc "$d")"
      q "INSERT OR IGNORE INTO domainlist (type,domain,enabled,comment) VALUES (3,'${de}',1,'youtube block (pi-youtube-block.sh)');"
      q "INSERT OR IGNORE INTO domainlist_by_group (domainlist_id,group_id) SELECT id,${gid} FROM domainlist WHERE type=3 AND domain='${de}';"
      # Pi-hole's tr_domainlist_add trigger auto-links every new domain to the
      # Default group 0 (whole network). Strip it so the block stays scoped to
      # this group only — matching what the admin UI does on group reassignment.
      [[ "$gid" != 0 ]] && q "DELETE FROM domainlist_by_group WHERE group_id=0 AND domainlist_id IN (SELECT id FROM domainlist WHERE type=3 AND domain='${de}');"
    done
    q "UPDATE 'group' SET enabled=1 WHERE id=${gid};"
    ;;
  off)
    if [[ -z "$gid" ]]; then echo "  group '${group}' not found — nothing to disable"; else
      q "UPDATE 'group' SET enabled=0 WHERE id=${gid};"
    fi
    ;;
  status) ;;
  *) echo "  unknown action: ${action}" >&2; exit 2 ;;
esac

if [[ "$action" != status ]]; then sudo pihole reloadlists >/dev/null 2>&1 || true; fi

# Report current state
gid="$(q "SELECT id FROM 'group' WHERE name='${g}';")"
if [[ -z "$gid" ]]; then echo "  group '${group}': absent"; exit 0; fi
en="$(q "SELECT enabled FROM 'group' WHERE id=${gid};")"
[[ "$en" == 1 ]] && state="ENABLED (blocking)" || state="disabled (not blocking)"
echo "  group '${group}' (id ${gid}): ${state}"
echo "  deny domains:"
q "SELECT '    - '||dl.domain FROM domainlist dl JOIN domainlist_by_group dbg ON dl.id=dbg.domainlist_id WHERE dbg.group_id=${gid} AND dl.type=3 ORDER BY dl.domain;" || true
clients="$(q "SELECT '    - '||c.ip||COALESCE(' ('||c.comment||')','') FROM client c JOIN client_by_group cbg ON c.id=cbg.client_id WHERE cbg.group_id=${gid} ORDER BY c.ip;")"
if [[ -n "$clients" ]]; then echo "  scoped to clients:"; echo "$clients"; else echo "  scoped to clients: (none — group applies to no devices)"; fi
REMOTE
}

# ── Fetch the client scope of the group on one Pi ─────────────────────────────
# Prints one client identifier (the `ip` column — a MAC or IP) per line, sorted.
# Empty output means the group is absent or has no clients on that Pi.
group_clients() {
    ssh "${SSH_OPTS[@]}" "${SSH_USER}@${1}" bash -s -- "$GROUP" <<'REMOTE' 2>/dev/null
g="$(printf '%s' "$1" | sed "s/'/''/g")"
sudo pihole-FTL sqlite3 /etc/pihole/gravity.db \
  "SELECT c.ip FROM client c JOIN client_by_group cbg ON c.id=cbg.client_id JOIN 'group' grp ON grp.id=cbg.group_id WHERE grp.name='${g}' ORDER BY c.ip;"
REMOTE
}

# ── Warn if the group's client scope differs across the target Pis ────────────
# A block that is scoped to a device on one Pi but not another silently fails
# whenever that Pi answers DNS — exactly the mismatch this guards against.
check_scope_consistency() {
    (( ${#TARGET_IPS[@]} < 2 )) && return 0
    declare -A scope; local ip union="" all=""
    for ip in "${TARGET_IPS[@]}"; do
        scope["$ip"]="$(group_clients "$ip")"
        all+="${scope[$ip]}"$'\n'
    done
    union="$(printf '%s' "$all" | grep -v '^[[:space:]]*$' | sort -u || true)"
    echo ""
    div_scope() { echo "----------------------------------------"; }
    div_scope
    if [[ -z "$union" ]]; then
        warn "  Scope check: '${GROUP}' has no client on any target Pi — it would block no device."
        return 0
    fi
    local mismatch=0 mac
    while IFS= read -r mac; do
        [[ -z "$mac" ]] && continue
        local missing=""
        for ip in "${TARGET_IPS[@]}"; do
            grep -qxF "$mac" <<< "${scope[$ip]}" || missing+="${ip} "
        done
        if [[ -n "$missing" ]]; then
            warn "  Scope MISMATCH: ${mac} present in '${GROUP}' but missing on: ${missing% }"
            mismatch=1
        fi
    done <<< "$union"
    if [[ "$mismatch" -eq 0 ]]; then
        success "  Scope check: '${GROUP}' client scope identical across all ${#TARGET_IPS[@]} Pis."
    else
        warn "  Fix by adding the missing MAC(s) to '${GROUP}' on the listed Pi(s), then re-run."
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
ACTION="${1:-}"
case "$ACTION" in
    on|off|status) shift ;;
    -h|--help|"") usage; [[ -z "$ACTION" ]] && exit 1 || exit 0 ;;
    *) error "Unknown action: ${ACTION}"; usage; exit 1 ;;
esac

if [[ $# -gt 0 ]]; then
    TARGET_IPS=("$@")
elif [[ ${#DEFAULT_PI_IPS[@]} -gt 0 && -n "${DEFAULT_PI_IPS[0]}" ]]; then
    TARGET_IPS=("${DEFAULT_PI_IPS[@]}")
else
    error "No Pi IPs given. Pass them as arguments, set PI_IPS, or create ${PI_CHECK_CONFIG/#"$HOME"/\~}."
    usage
    exit 1
fi

case "$ACTION" in
    on)  arrow "Enabling YouTube block ('${GROUP}') on ${#TARGET_IPS[@]} Pi(s)…" ;;
    off) arrow "Disabling YouTube block ('${GROUP}') on ${#TARGET_IPS[@]} Pi(s)…" ;;
    status) arrow "YouTube block status ('${GROUP}') on ${#TARGET_IPS[@]} Pi(s)…" ;;
esac

rc=0
for ip in "${TARGET_IPS[@]}"; do
    banner "${ip}"
    if remote "$ip" "$ACTION" "$GROUP" "$DOMAINS"; then
        [[ "$ACTION" == status ]] || success "${ip}: ${ACTION} applied"
    else
        error "${ip}: failed"
        rc=1
    fi
done

check_scope_consistency
exit "$rc"
