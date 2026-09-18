#!/usr/bin/env bash
# Read-only health check for the Nix + asdf layer: reports per-tool status
# regardless of which manager provides the binary.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

COL=16
pass() { printf "${GREEN}  ✔  %-${COL}s${RESET}  ${BOLD}%s${RESET}\n" "${1}" "${2:-}"; }
fail() { printf "${RED}  ✘  %-${COL}s${RESET}\n" "${1}"; }

echo "--------------------------------"
cog_msg "Nix / asdf Health Check ($OS)"
echo "--------------------------------"
echo

echo -e "${BOLD}Nix${RESET}"
if command -v nix &>/dev/null; then
    pass "nix" "$(nix --version)"
else
    fail "nix"
fi

if [[ "$OS" == "macos" ]]; then
    if [[ -x /run/current-system/sw/bin/darwin-rebuild ]]; then
        pass "nix-darwin" "installed"
    else
        fail "nix-darwin"
    fi
    if [[ -e /nix/var/nix/profiles/system ]]; then
        gen="$(readlink /nix/var/nix/profiles/system 2>/dev/null || echo unknown)"
        pass "system generation" "$gen"
    else
        fail "system generation"
    fi
elif [[ "$OS" == "debian" ]]; then
    if command -v home-manager &>/dev/null; then
        pass "home-manager" "$(home-manager --version 2>/dev/null || echo installed)"
    else
        fail "home-manager"
    fi
else
    error "Unsupported OS: ${OS}"; exit 1
fi
echo

echo -e "${BOLD}asdf${RESET}"
if command -v asdf &>/dev/null; then
    pass "asdf" "$(asdf version 2>/dev/null)"
    echo
    echo -e "  ${BOLD}Plugins pinned in ~/.tool-versions:${RESET}"
    if [[ -f "$HOME/.tool-versions" ]]; then
        while read -r name version; do
            [[ -z "$name" ]] && continue
            installed="$(asdf list "$name" 2>/dev/null | tr -d ' *' | grep -Fx "$version" || true)"
            if [[ -n "$installed" ]]; then
                pass "  $name" "$version"
            else
                fail "  $name (pinned $version, not installed)"
            fi
        done < "$HOME/.tool-versions"
    else
        warn "  No ~/.tool-versions found"
    fi
else
    fail "asdf"
fi

echo
echo "--------------------------------"
success "Nix / asdf health check complete."
echo "--------------------------------"
