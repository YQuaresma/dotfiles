#!/usr/bin/env bash
# Creates the folders, folder symlinks, and file symlinks this dotfiles repo depends
# on under $HOME. Replaces GNU Stow: symlinks/home/<rel> mirrors $HOME/<rel> 1:1, no
# package indirection.
#
# Usage:
#   bash sys-symlinks.sh
set -euo pipefail

# The repo root is derived from this script's own resolved location
# (<repo>/symlinks/home/bin/sys-symlinks.sh), never from a hardcoded path: the
# clone may live anywhere, and ~/bin is itself one of the symlinks this script
# creates, so `pwd -P` lands in the real repo either way.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd -P)"

# ~/.dotfiles is the canonical entry point every other script references; it is
# linked to REPO_ROOT below, and everything else resolves off the alias.
DOTFILES_DIR="$HOME/.dotfiles"
SYMLINKS_HOME="$DOTFILES_DIR/symlinks/home"
SYMLINKS_DEVELOPER="$DOTFILES_DIR/symlinks/Developer"
source "${SCRIPT_DIR}/functions.sh"

# Linux/macOS branch for the handful of OS-specific symlinks below (currently
# only ~/.config/ghostty/config.linux, Ghostty's Linux-only keybind include).
OS="$(detect_os)"

if [[ ! -d "$REPO_ROOT/symlinks/home" ]]; then
    error "Cannot locate the repo root from ${SCRIPT_DIR} (got ${REPO_ROOT})."
    error "Run this script from its place in the clone: bash symlinks/home/bin/sys-symlinks.sh"
    exit 1
fi

echo "--------------------------------"
cog_msg "Creating folders and symlinks..."
echo "--------------------------------"

# Group 1 — folders to create
folders=(
    "$HOME/.config"
    "$HOME/.config/ghostty"
    "$HOME/.config/zed"
    "$HOME/.ssh"
    "$HOME/.claude"
    "$HOME/Developer/AI"
    "$HOME/Developer/Documents"
    "$HOME/Developer/Docker"
    "$HOME/Developer/Docker/Volumes"
    "$HOME/Developer/Support"
    "$HOME/Developer/Repos/Personal"
    "$HOME/Developer/Repos/Sandbox"
    "$HOME/Developer/Repos/Work"
)

# Group 2 — folder symlinks ("source|destination"; destination is the symlink created)
folder_links=(
    "$REPO_ROOT|$HOME/.dotfiles"
    "$SYMLINKS_HOME/bin|$HOME/bin"
    "$SYMLINKS_HOME/.agents|$HOME/.agents"
    "$SYMLINKS_HOME/.agents/skills|$HOME/.claude/skills"
    "$SYMLINKS_HOME/.agents/skills|$HOME/.codex/skills"
    "$SYMLINKS_HOME/.githooks|$HOME/.githooks"
)

# Group 3 — file symlinks ("source|destination"; destination is the symlink created)
file_links=(
    "$SYMLINKS_DEVELOPER/Docker/docker-compose.yaml|$HOME/Developer/Docker/docker-compose.yaml"
    "$SYMLINKS_HOME/.agents/AGENTS.md|$HOME/.claude/CLAUDE.md"
    "$SYMLINKS_HOME/.agents/AGENTS.md|$HOME/.codex/AGENTS.md"
    "$SYMLINKS_HOME/.agents/AGENTS.md|$HOME/.config/opencode/AGENTS.md"
    "$SYMLINKS_HOME/.agents/AGENTS.md|$HOME/.copilot/copilot-instructions.md"
    "$SYMLINKS_HOME/.agents/AGENTS.md|$HOME/.gemini/GEMINI.md"
    "$SYMLINKS_HOME/.agents/AGENTS.md|$HOME/.omp/agent/AGENTS.md"
    "$SYMLINKS_HOME/.agents/RULES.md|$HOME/.omp/agent/RULES.md"
    "$SYMLINKS_HOME/.bashrc.alias|$HOME/.bashrc.alias"
    "$SYMLINKS_HOME/.bashrc|$HOME/.bashrc"
    "$SYMLINKS_HOME/.config/ghostty/config|$HOME/.config/ghostty/config"
    "$SYMLINKS_HOME/.config/zed/settings.json|$HOME/.config/zed/settings.json"
    "$SYMLINKS_HOME/.fzf.zsh|$HOME/.fzf.zsh"
    "$SYMLINKS_HOME/.gitconfig|$HOME/.gitconfig"
    "$SYMLINKS_HOME/.gitignore_global|$HOME/.gitignore_global"
    "$SYMLINKS_HOME/.p10k.zsh|$HOME/.p10k.zsh"
    "$SYMLINKS_HOME/.profile|$HOME/.profile"
    "$SYMLINKS_HOME/.zprofile|$HOME/.zprofile"
    "$SYMLINKS_HOME/.zshrc|$HOME/.zshrc"
    "$SYMLINKS_HOME/.zshrc.alias|$HOME/.zshrc.alias"
)

# Linux-only: Ghostty's Ctrl-based keybind include (loaded from the shared
# config via `config-file = ?config.linux`). Not linked on macOS so the "?"
# optional include stays a genuine no-op there instead of picking up Linux keybinds.
if [[ "$OS" == "debian" ]]; then
    file_links+=("$SYMLINKS_HOME/.config/ghostty/config.linux|$HOME/.config/ghostty/config.linux")
fi

renamed=()

# Prints an absolute path with $HOME collapsed to ~, for display only.
disp() {
    local p="$1"
    [[ "$p" == "$HOME"* ]] && p="~${p#$HOME}"
    echo "$p"
}

# Creates a symlink at $dest pointing to $src, backing up any pre-existing
# non-symlink (or wrongly-targeted symlink) at $dest to "<dest>_bak" first.
link() {
    local src="$1" dest="$2"

    # Compare resolved targets, not the literal readlink text: an existing link
    # written through a differently-spelled but equivalent path (e.g. a symlinked
    # parent directory) is already correct and must not be "backed up".
    if [[ -L "$dest" ]]; then
        local have want
        have="$(cd -P "$dest" 2>/dev/null && pwd -P || readlink "$dest")"
        want="$(cd -P "$src" 2>/dev/null && pwd -P || echo "$src")"
        if [[ "$have" == "$want" ]]; then
            tick "Already linked: $(disp "$dest") -> $(disp "$src")"
            return
        fi
    fi

    if [[ -e "$dest" || -L "$dest" ]]; then
        local backup="${dest}_bak"
        [[ -e "$backup" || -L "$backup" ]] && backup="${dest}_bak.$(date +%s)"
        warn "$(disp "$dest") exists — backing up to $(basename "$backup")"
        mv "$dest" "$backup"
        renamed+=("$(disp "$dest") → $(disp "$backup")")
    fi

    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
    arrow "Linked: $(disp "$dest") -> $(disp "$src")"
}

# Create Group 1 folders, then lock down ~/.ssh (ssh itself enforces 700).
for dir in "${folders[@]}"; do
    if [ -d "$dir" ]; then
        tick "Already exists: $(disp "$dir")"
    else
        mkdir -p "$dir"
        arrow "Created directory: $(disp "$dir")"
    fi
done
chmod 700 "$HOME/.ssh"
echo

# Create Group 2 folder symlinks.
for entry in "${folder_links[@]}"; do
    IFS='|' read -r src dest <<< "$entry"
    link "$src" "$dest"
done

echo

# Create Group 3 file symlinks.
for entry in "${file_links[@]}"; do
    IFS='|' read -r src dest <<< "$entry"
    link "$src" "$dest"
done

echo
success "Symlinking complete (check warnings above for any skips/backups)."

# Clear any local core.hooksPath left over from before this repo relied on the
# global ~/.githooks hook (see symlinks/home/.gitconfig) — a local override, even
# pointing at a directory with no hook file, blocks fallback to the global one.
git -C "$DOTFILES_DIR" config --unset core.hooksPath 2>/dev/null || true

# List any pre-existing files link() backed up instead of overwriting.
if [ ${#renamed[@]} -gt 0 ]; then
    echo
    warn "Pre-existing files were backed up:"
    for r in "${renamed[@]}"; do
        echo "  $r"
    done
fi
