#!/usr/bin/env bash
# Minimum requirements to clone this repo on a brand-new machine. Download
# standalone to $HOME and run — it installs git and the gh CLI, authenticates
# with GitHub (no SSH key needed — auth and the clone below both go over
# HTTPS via gh), then clones the repo and links ~/.dotfiles to it. Deletes
# itself when done.
#
# Usage:
#   bash ~/initialise.sh
#
# Non-interactive auth: write the PAT to a file and point GH_TOKEN_FILE at it.
#   printf '%s' '<pat>' > ~/.gh-token && chmod 600 ~/.gh-token
#   GH_TOKEN_FILE=~/.gh-token bash ~/initialise.sh && rm -f ~/.gh-token
#
# Do NOT pass the token itself on the command line (GH_TOKEN=<pat> bash …):
# it lands in shell history and is readable in /proc/<pid>/environ and `ps eww`
# by every process this user owns, for the whole run.
#
# functions.sh isn't on disk yet at any point this script runs (that's the whole
# reason it exists), so every stage below uses $OSTYPE//etc/debian_version
# directly instead of detect_os().
set -euo pipefail

# ---------------------------------
# Update APT Metadata (Ubuntu)
# ---------------------------------
install_apt_metadata() {
    [[ -f /etc/debian_version ]] || return 0

    echo "--------------------------------"
    echo "Updating system packages..."
    echo "--------------------------------"
    # Remove broken ubuntu-virt apt hook before any apt operation (functions.sh not available yet)
    if [[ -f /etc/apt/apt.conf.d/99-ubuntu-virt.conf ]] && [[ ! -f /usr/bin/apt_hook_ubuntu_virt ]]; then
        echo "Removing broken apt hook: 99-ubuntu-virt.conf"
        sudo rm -f /etc/apt/apt.conf.d/99-ubuntu-virt.conf
    fi
    sudo apt-get update < /dev/null
}

# ---------------------------------
# Install Homebrew (macOS)
# ---------------------------------
install_homebrew() {
    [[ "$OSTYPE" == darwin* ]] || return 0

    echo "--------------------------------"
    echo "Installing Homebrew..."
    echo "--------------------------------"

    if ! command -v brew &>/dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1
        if ! command -v brew &>/dev/null; then
            return 1
        fi
    else
        echo "Homebrew already installed."
    fi

    if [ -d "/opt/homebrew/bin" ]; then
        export PATH="/opt/homebrew/bin:$PATH"
    elif [ -d "/usr/local/bin" ]; then
        export PATH="/usr/local/bin:$PATH"
    fi

    brew update
}

# ---------------------------------
# Bootstrap Base Tools
# ---------------------------------
# macOS: git comes from Xcode Command Line Tools, not Homebrew — installing it via
# brew just to uninstall it minutes later (once Nix takes over) is a pointless
# round-trip. curl is already satisfied by the system copy (install_homebrew above
# already relied on it), and zsh ships built into macOS (5.9+), no need for
# Homebrew's either. Ubuntu: git, curl (not guaranteed present on minimal/cloud
# images), zsh (Ubuntu doesn't ship it, and install/setup.sh sets it as the
# default shell later). build-essential/ca-certificates/software-properties-common
# aren't needed just to clone — install/setup.sh installs those post-clone.
install_bootstrap() {
    if [[ "$OSTYPE" == darwin* ]]; then
        if command -v git &>/dev/null; then
            echo "git already installed: $(git --version)"
        else
            echo "git not found — triggering the Xcode Command Line Tools installer..."
            xcode-select --install
            echo "Finish the Command Line Tools install in the popup, then re-run this script."
            exit 1
        fi

    elif [[ -f /etc/debian_version ]]; then
        local pkgs=()
        command -v git  &>/dev/null && echo "git already installed: $(git --version)" || pkgs+=(git)
        command -v curl &>/dev/null && echo "curl already installed." || pkgs+=(curl)
        command -v zsh  &>/dev/null && echo "zsh already installed."  || pkgs+=(zsh)
        if [[ ${#pkgs[@]} -gt 0 ]]; then
            sudo apt install -y "${pkgs[@]}" < /dev/null
        fi

    else
        echo "Unsupported OS. Install git (and curl, zsh on Linux) manually and re-run."
        exit 1
    fi
}

# ---------------------------------
# Install & Authenticate GitHub CLI
# ---------------------------------
install_gh() {
    if command -v gh &>/dev/null; then
        echo "gh already installed: $(gh --version | head -1)"
    else
        echo "Installing gh CLI..."

        if [[ "$OSTYPE" == darwin* ]]; then
            brew install gh
        elif [[ -f /etc/debian_version ]]; then
            sudo mkdir -p -m 755 /etc/apt/keyrings
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
            sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
                | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            sudo apt-get update < /dev/null
            sudo apt-get install -y gh < /dev/null
        else
            echo "Unsupported OS. Install gh manually and re-run."
            exit 1
        fi
    fi

    # gh auth status already reports success (and the account source, e.g.
    # "(GH_TOKEN)") when GH_TOKEN/GITHUB_TOKEN is set — no need to special-case it.
    if gh auth status &>/dev/null; then
        echo "gh already authenticated."
        return 0
    fi

    if [[ -n "${GH_TOKEN_FILE:-}" ]]; then
        [[ -r "$GH_TOKEN_FILE" ]] || { echo "GH_TOKEN_FILE not readable: $GH_TOKEN_FILE" >&2; return 1; }
        echo "Authenticating with GitHub from ${GH_TOKEN_FILE}..."
        # Token reaches gh over stdin only — never argv, never the environment.
        gh auth login --with-token < "$GH_TOKEN_FILE"
        return 0
    fi

    echo "Authenticating with GitHub..."
    gh auth login
}

# ---------------------------------
# Clone Dotfiles Repo
# ---------------------------------
clone_dotfiles() {
    local target="$HOME/Developer/Repos/dotfiles"

    if [[ -d "$target/.git" ]]; then
        echo "Dotfiles already cloned at $target."
    else
        echo "Cloning dotfiles repo..."
        mkdir -p "$(dirname "$target")"
        gh repo clone YQuaresma/.dotfiles "$target"
    fi

    if [[ -L "$HOME/.dotfiles" && "$(readlink "$HOME/.dotfiles")" == "$target" ]]; then
        echo "~/.dotfiles already linked."
    elif [[ -e "$HOME/.dotfiles" ]]; then
        echo "~/.dotfiles exists and isn't the expected symlink — leaving it alone." >&2
    else
        ln -s "$target" "$HOME/.dotfiles"
        echo "Linked: ~/.dotfiles -> $target"
    fi
}

# ---------------------------------
# Main
# ---------------------------------
main() {
    install_apt_metadata
    install_homebrew
    install_bootstrap
    install_gh
    clone_dotfiles

    echo "--------------------------------"
    echo "Bootstrap complete."
    echo "--------------------------------"
    echo "Next — hand off to install/setup.sh:"
    echo
    echo "  cd ~/.dotfiles && bash install/setup.sh"
    echo
    echo "See README.md's Quick Start for details, including cloning"
    echo "somewhere other than ~/Developer/Repos/dotfiles."
    echo

    # Downloaded standalone to run once — remove it now that its job is done.
    [[ -f "$0" ]] && rm -- "$0"
}

main "$@"
