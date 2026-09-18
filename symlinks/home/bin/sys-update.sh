#!/usr/bin/env bash
# System update — Homebrew (macOS) or apt/snap/firmware (Ubuntu), plus Nix and asdf
# on both. Every stage is a function; main() at the bottom calls them in order.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/functions.sh"
OS="$(detect_os)"

# asdf tools to keep installed, always at the latest available release. Single
# spot to add a tool: add its name here (plus ASDF_PLUGIN_REPOS, only if the
# plugin's shortname doesn't resolve via the official/default asdf plugin registry).
ASDF_PLUGINS=(
    dotnet-core
    golang
    nodejs
    pnpm
    terraform
)

declare -A ASDF_PLUGIN_REPOS=(
    [terraform]="https://github.com/asdf-community/asdf-hashicorp.git"
)

# ---------------------------------
# Update Homebrew
# ---------------------------------
update_brew() {
    banner "Updating Homebrew & Formulae ..."
    brew update
    brew upgrade
}

# ---------------------------------
# Update Ubuntu (APT)
# ---------------------------------
update_ubuntu() {
    banner "Updating Ubuntu packages..."
    sudo apt update
    sudo apt full-upgrade -y
    sudo apt autoremove -y
    sudo apt clean
}

# ---------------------------------
# Update Ubuntu Snaps
# ---------------------------------
update_snaps() {
    banner "Updating Snap packages..."
    sudo snap refresh
}

# ---------------------------------
# Update Firmware (fwupd)
# ---------------------------------
update_firmware() {
    banner "Checking firmware updates..."
    sudo fwupdmgr refresh
    sudo fwupdmgr get-updates
    sudo fwupdmgr update --no-reboot-check || warn "No firmware updates or update failed."
}

# ---------------------------------
# Update Dotfiles Repo
# ---------------------------------
# Fast-forwards ~/.dotfiles' local main from origin, so the flake.lock/ASDF_PLUGINS
# read by update_nix/update_asdf below are current. Skips (warn-only) whenever
# it's not safely automatable: not a git repo, not on main, dirty working tree,
# or diverged/behind in a way a fast-forward can't resolve.
update_dotfiles_repo() {
    local repo="$HOME/.dotfiles"

    if [[ ! -d "$repo/.git" ]]; then
        warn "~/.dotfiles isn't a git repo — skipping dotfiles update."
        return 0
    fi

    local branch
    branch="$(git -C "$repo" symbolic-ref --short HEAD 2>/dev/null || true)"
    if [[ "$branch" != "main" ]]; then
        warn "~/.dotfiles is on '${branch:-detached HEAD}', not main — skipping dotfiles update."
        return 0
    fi

    if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
        warn "~/.dotfiles has local changes — skipping dotfiles update."
        return 0
    fi

    arrow "Checking for dotfiles updates (main)..."
    if ! git -C "$repo" fetch --quiet origin main; then
        warn "Failed to fetch ~/.dotfiles — skipping dotfiles update."
        return 0
    fi

    local incoming
    incoming="$(git -C "$repo" log --oneline HEAD..origin/main 2>/dev/null || true)"
    if [[ -z "$incoming" ]]; then
        tick "~/.dotfiles already up to date."
        echo
        return 0
    fi

    # This repo updates itself and then runs the scripts it just pulled —
    # nix-update.sh below activates the new tree with sudo. That makes an
    # unattended merge equivalent to remote root execution, so show what is
    # coming, check that it is signed, and require an explicit yes.
    highlight "Incoming commits:"
    echo "$incoming" | sed 's/^/    /'

    local unsigned=0 c
    while IFS= read -r c; do
        [[ -z "$c" ]] && continue
        git -C "$repo" verify-commit "$c" >/dev/null 2>&1 || unsigned=$((unsigned + 1))
    done < <(git -C "$repo" rev-list HEAD..origin/main)

    if (( unsigned > 0 )); then
        warn "${unsigned} incoming commit(s) have no verifiable signature."
        warn "Expected for GitHub web merges (signed by GitHub's key); suspicious otherwise."
    else
        tick "All incoming commits carry a good signature."
    fi

    # Fail closed: no tty means nobody can answer, so do not apply.
    if [[ "${DOTFILES_UPDATE_ASSUME_YES:-0}" == "1" ]]; then
        info "DOTFILES_UPDATE_ASSUME_YES=1 — applying without prompting."
    elif [[ ! -t 0 ]]; then
        warn "Not an interactive shell — skipping dotfiles update."
        warn "Re-run interactively, or set DOTFILES_UPDATE_ASSUME_YES=1 to accept unreviewed updates."
        echo
        return 0
    elif ! confirm "Apply these updates to ~/.dotfiles?"; then
        warn "Declined — skipping dotfiles update."
        echo
        return 0
    fi

    if ! git -C "$repo" merge --ff-only --quiet origin/main; then
        warn "~/.dotfiles main can't fast-forward to origin/main — skipping dotfiles update."
        return 0
    fi
    success "~/.dotfiles updated."
    echo
}

# ---------------------------------
# Update System Packages
# ---------------------------------
# macOS: Homebrew (fatal on failure). Ubuntu: apt (fatal on failure), snap,
# firmware (both warn-only).
update_system_packages() {
    if [[ "$OS" == "macos" ]]; then
        if ! update_brew; then
            error "Problem updating Homebrew."
            exit 1
        fi

    elif [[ "$OS" == "debian" ]]; then
        if ! update_ubuntu; then
            error "Problem updating Ubuntu."
            exit 1
        fi
        if ! update_snaps; then
            warn "Snap update failed."
        fi
        if ! update_firmware; then
            warn "Firmware update failed."
        fi

    else
        error "Unsupported OS: ${OS}"; exit 1
    fi
    echo
}

# ---------------------------------
# Update Nix Packages
# ---------------------------------
# macOS: CLI utils, azure-cli, azurite, claude-code, fonts, oh-my-zsh/theme/plugins.
update_nix() {
    banner "Updating Nix packages..."
    "$HOME/.dotfiles/nix/nix-update.sh"
}

# ---------------------------------
# Update asdf Dev Tools
# ---------------------------------
# Installs/updates every plugin in ASDF_PLUGINS to its latest available release,
# pinning that version globally (writes to ~/.tool-versions directly — a real,
# local, untracked file, not repo-managed via symlinks/home/).
update_asdf() {
    banner "Updating asdf plugins + tool versions..."
    asdf plugin update --all

    local name current latest failed=0
    for name in "${ASDF_PLUGINS[@]}"; do
        if ! asdf plugin list 2>/dev/null | grep -qx "$name"; then
            cog_msg "$name: new plugin — adding..."
            if [[ -n "${ASDF_PLUGIN_REPOS[$name]:-}" ]]; then
                asdf plugin add "$name" "${ASDF_PLUGIN_REPOS[$name]}"
            else
                asdf plugin add "$name"
            fi
            success "$name: plugin added"
        fi

        current="$(asdf current "$name" 2>/dev/null | tail -1 | awk '{print $2}')" || current=""
        latest="$(asdf latest "$name")"
        if [[ "$latest" == "$current" ]]; then
            success "$name: $latest (latest)"
        else
            cog_msg "$name: installing $latest..."
            # Only pin .tool-versions on a confirmed successful install — asdf
            # install can fail (e.g. upstream plugin bugs) without asdf itself
            # aborting this loop, since update_asdf is called as
            # `update_asdf || warn ...` in main(), which disables `set -e`
            # for the whole function body.
            if asdf install "$name" "$latest"; then
                asdf set -u "$name" "$latest"
                success "$name: ${current:-none} -> $latest"
            else
                warn "$name: failed to install $latest (kept ${current:-none})"
                failed=1
            fi
        fi
    done

    return "$failed"
}

# ---------------------------------
# Check Reboot Required
# ---------------------------------
check_reboot_required() {
    if [[ "$OS" == "debian" ]] && [ -f /var/run/reboot-required ]; then
        highlight "Reboot required to complete updates."
    fi
}

# ---------------------------------
# Main
# ---------------------------------
main() {
    banner "Update Summary"

    local had_warnings=0

    update_dotfiles_repo
    update_system_packages
    update_nix || had_warnings=1
    update_asdf || had_warnings=1

    check_reboot_required

    echo
    banner "System Update has completed. (sys-update.sh)"
    if [[ "$had_warnings" -eq 0 ]]; then
        success "All selected updates completed!"
    else
        warn "Updates completed with warnings — see above."
    fi
}

main "$@"
