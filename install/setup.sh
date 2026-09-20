#!/usr/bin/env bash
# Idempotent post-clone installer: symlinks dotfiles into $HOME, installs the full
# toolchain (Nix, asdf via sys-update.sh), sets the default shell. Assumes the repo
# is already on disk (install/initialise.sh, or a manual clone, got it there) —
# $HOME/.dotfiles is a symlink to wherever the developer chose to put it. Safe to
# re-run any time; every stage is a function, main() at the bottom calls them in
# order.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "$DOTFILES_DIR/symlinks/home/bin/functions.sh"
OS="$(detect_os)"

# ---------------------------------
# Print Setup Banner
# ---------------------------------
print_banner() {
    local banner_type="$1"

    if [[ "$banner_type" == "start" ]]; then
        echo "--------------------------------"
        echo "Starting $OS Dev Machine Setup"
        echo "--------------------------------"
        echo
        return 0
    fi

    echo "--------------------------------"
    echo "$OS Dev Machine Setup Finished!"
    echo "--------------------------------"
    echo -e "${BOLD}${ICON_WARN}${ICON_INFO} Please restart your terminal or run 'source ~/.zshrc' to apply changes.${ICON_INFO}${ICON_WARN}${RESET}"
    echo
    echo -e "${BOLD}${ICON_INFO} Optional installs (not run automatically):${RESET}"
    echo -e "    bash $DOTFILES_DIR/install/install-python.sh    # Python via uv"
    echo -e "    bash $DOTFILES_DIR/install/install-docker.sh    # Docker Engine/Desktop"
    echo -e "    bash $DOTFILES_DIR/install/install-apps-gui.sh  # GUI apps (browsers, editors, dev tools)"
    echo -e "    bash $DOTFILES_DIR/install/install-ghostty.sh   # Ghostty terminal"
    echo -e "    bash $DOTFILES_DIR/install/install-helium.sh    # Helium Browser"
}

# ---------------------------------
# Symlink Dotfiles
# ---------------------------------
# Must run before install_packages/run-nix-install below — subsequent stages
# (asdf, shell config) depend on the rest of $HOME being wired up first.
run-sys-symlinks() {
    bash "$DOTFILES_DIR/symlinks/home/bin/sys-symlinks.sh"
    echo
}

# ---------------------------------
# Install Packages
# ---------------------------------
# Ubuntu only — build toolchain, CA certs, PPA management have no Nix equivalent
# worth chasing. Everything else is Nix-managed (nix/home/packages.nix) on both
# OSes — see run-sys-update below.
install_packages() {
    [[ "$OS" == "debian" ]] || return 0

    echo "--------------------------------"
    cog_msg "Installing APT packages..."
    echo "--------------------------------"

    export DEBIAN_FRONTEND=noninteractive
    sudo apt install -y build-essential ca-certificates software-properties-common < /dev/null
    echo
}

# ---------------------------------
# Install Nix
# ---------------------------------
# Only installs the `nix` binary here — switching to the current generation and
# everything past that (asdf, apt/brew upgrade) happens in run-sys-update below,
# so install and routine update converge on one code path.
run-nix-install() {
    bash "$DOTFILES_DIR/nix/nix-install.sh"
    echo
}

# ---------------------------------
# Run Full System Update
# ---------------------------------
# Full update pass — Nix switch (+ flake bump; CLI utils, azure-cli, azurite,
# claude-code, fonts, oh-my-zsh/theme/plugins, asdf itself), asdf dev tools
# (always latest), and OS package manager (apt full-upgrade / brew upgrade). Same
# script routine maintenance uses (sys-update.sh) — single source of truth, not
# duplicated install-time logic. Azure Functions Core Tools stays out of this
# pipeline entirely — nixpkgs still can't produce a working build (ASP.NET Core
# runtime missing from the closure); install-azure-functions.sh /
# remove-azure-functions.sh kept for ad-hoc/manual use.
run-sys-update() {
    bash "$DOTFILES_DIR/symlinks/home/bin/sys-update.sh"
    echo
}

# ---------------------------------
# Set Default Shell
# ---------------------------------
set_default_shell() {
    echo "--------------------------------"
    cog_msg "Setting Zsh as default shell..."
    echo "--------------------------------"
    local zsh_path
    zsh_path="$(command -v zsh)"
    if [ "$SHELL" = "$zsh_path" ]; then
        warn "Zsh is already the default shell."
    elif [[ "$OS" == "macos" ]]; then
        grep -qxF "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells > /dev/null
        sudo chsh -s "$zsh_path" "$USER"
        success "Zsh set as default shell (takes effect on next login)."
    elif [[ "$OS" == "debian" ]]; then
        sudo usermod -s "$zsh_path" "$USER"
        success "Zsh set as default shell (takes effect on next login)."
    else
        error "Unsupported OS: ${OS}"; exit 1
    fi
    echo
}

# ---------------------------------
# Main
# ---------------------------------
main() {
    print_banner "start"
    run-sys-symlinks
    install_packages
    run-nix-install
    run-sys-update
    set_default_shell
    print_banner "summary"
}

main "$@"
