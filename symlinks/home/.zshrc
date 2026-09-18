# ~/.zshrc — Cross-platform (macOS + Linux)

# -------------------------------------------------------------------
# SECTION: POWERLEVEL10K INSTANT PROMPT
# Must stay at the very top for instant prompt
# -------------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# -------------------------------------------------------------------
# SECTION: Detect OS
# -------------------------------------------------------------------
case "$OSTYPE" in
  linux-gnu*) OS="linux" ;;     # Ubuntu/Linux
  darwin*)    OS="macos" ;;     # macOS
  *)          OS="unknown" ;;
esac

# -------------------------------------------------------------------
# SECTION: Homebrew PATH (macOS)
# -------------------------------------------------------------------
if [[ "$OS" == "macos" ]]; then
    if [ -d "/opt/homebrew/bin" ]; then
        export PATH="/opt/homebrew/bin:$PATH"
    elif [ -d "/usr/local/bin" ]; then
        export PATH="/usr/local/bin:$PATH"
    fi
    export HOMEBREW_NO_ENV_HINTS=1
fi

# -------------------------------------------------------------------
# SECTION: Environment Variables
# -------------------------------------------------------------------
export CLICOLOR=1
export EDITOR=nvim
export GPG_TTY="$(tty)"

export GH_NO_UPDATE_NOTIFIER=1
export GH_CONFIG_DIR="$HOME/.config/gh"
# Deliberately NOT setting TF_CLI_ARGS_apply="-auto-approve" here. A global
# export removes the last confirmation before `terraform apply` mutates or
# destroys real infrastructure, in every workspace including production, and it
# is inherited by every subshell, script, CI runner and coding agent. Opt in per
# project instead (direnv, or `TF_CLI_ARGS_apply=-auto-approve terraform apply`).

if [[ "$OS" == "macos" ]]; then
    export ICLOUD_DRIVE="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
fi

export DEV_ROOT="$HOME/Developer"
export DEV_BIN="$DEV_ROOT/bin"
export DEV_REPOS="$DEV_ROOT/Repos"
export DEV_SUPPORT="$DEV_ROOT/Support"

export EZA_COLORS="da=38;5;208"

# -------------------------------------------------------------------
# SECTION: History Options
# -------------------------------------------------------------------
HISTSIZE=9999
SAVEHIST=999999
setopt APPEND_HISTORY        # Append to history file
setopt SHARE_HISTORY         # Share history across sessions
setopt HIST_IGNORE_DUPS      # Ignore duplicate commands
setopt HIST_REDUCE_BLANKS    # Remove superfluous blanks

# -------------------------------------------------------------------
# SECTION: PATH Updates
# -------------------------------------------------------------------
# Home /bin
[ -d "$HOME/bin" ] && export PATH="$HOME/bin:$PATH"
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"

# DEV /bin
[ -d "$DEV_BIN" ] && export PATH="$DEV_BIN:$PATH"

# asdf shims — early in PATH so asdf-pinned tool versions win over any system copy.
# Populated by asdf: node, go, terraform, pnpm, dotnet.
[ -d "$HOME/.asdf/shims" ] && export PATH="$HOME/.asdf/shims:$PATH"

# Jetbrains Toolbox
if [[ "$OS" == "linux" ]]; then
    JETBRAINS_TOOLBOX="$HOME/.local/share/JetBrains/Toolbox/scripts"
else
    JETBRAINS_TOOLBOX="$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
fi
[ -d "$JETBRAINS_TOOLBOX" ] && export PATH="$PATH:$JETBRAINS_TOOLBOX"

# -------------------------------------------------------------------
# SECTION: Go
# -------------------------------------------------------------------
# Go binary itself is asdf-managed (both OSes)
# — resolved via the ~/.asdf/shims PATH entry above. This is just Go's workspace
# tools dir (`go install`), independent of how the `go` binary itself was installed.
[ -d "$HOME/go/bin" ] && export PATH="$PATH:$HOME/go/bin"

# -------------------------------------------------------------------
# SECTION: .NET Global tools
# -------------------------------------------------------------------
# .NET SDK itself is asdf-managed (both OSes)
# — resolved via the ~/.asdf/shims PATH entry above. This is just .NET's global tools
# dir (`dotnet tool install -g`), independent of how the SDK itself was installed.
DOTNET_TOOLS="$HOME/.dotnet/tools"
[ -d "$DOTNET_TOOLS" ] && export PATH="$PATH:$DOTNET_TOOLS"

export DOTNET_CLI_TELEMETRY_OPTOUT=1

# -------------------------------------------------------------------
# SECTION: Curl (macOS — Homebrew curl is keg-only, must be added manually)
# -------------------------------------------------------------------
if [[ "$OS" == "macos" ]]; then
    CURL_BIN="/opt/homebrew/opt/curl/bin"
    [ -d "$CURL_BIN" ] && export PATH="$CURL_BIN:$PATH"
fi

# -------------------------------------------------------------------
# SECTION: Python (via uv)
# -------------------------------------------------------------------
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# -------------------------------------------------------------------
# SECTION: pnpm
# -------------------------------------------------------------------
if [[ "$OS" == "macos" ]]; then
    export PNPM_HOME="$HOME/Library/pnpm"
else
    export PNPM_HOME="$HOME/.local/share/pnpm"
fi
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# -------------------------------------------------------------------
# SECTION: Oh My Zsh & Powerlevel10K
# -------------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
# Theme + zsh-autosuggestions/zsh-syntax-highlighting are Nix-provisioned (read-only
# store paths) into ~/.oh-my-zsh-custom — see ~/.dotfiles/nix/home/zsh.nix. Kept
# outside $ZSH itself since that symlink is read-only.
export ZSH_CUSTOM="$HOME/.oh-my-zsh-custom"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Enable plugins (order matters: autosuggestions last in array is fine, syntax-highlighting will be sourced manually)
plugins=(
    git
    gitfast
    git-extras
    git-auto-fetch
    node
    npm
    terraform
    azure
    direnv
    zsh-autosuggestions
)

# Source Oh My Zsh
[ -s "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"

# Powerlevel10K config
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Syntax highlighting must be loaded last
[[ -f "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] &&
    source "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

[ -s "$ZSH/oh-my-zsh.sh" ] && ZSH_HIGHLIGHT_STYLES[globbing]='fg=214'
# -------------------------------------------------------------------
# SECTION: FZF key bindings & completion
# -------------------------------------------------------------------
if command -v fzf >/dev/null 2>&1; then
    [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh || eval "$(fzf --zsh)"
fi
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"

# -------------------------------------------------------------------
# SECTION: Zoxide
# -------------------------------------------------------------------
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init --cmd cd zsh)"
fi

# -------------------------------------------------------------------
# SECTION: Docker completions
# -------------------------------------------------------------------
[ -d ~/.docker/completions ] && fpath=(~/.docker/completions $fpath)

# -------------------------------------------------------------------
# SECTION: PATH hygiene
# -------------------------------------------------------------------
typeset -U PATH

# -------------------------------------------------------------------
# SECTION: Initialize completions
# -------------------------------------------------------------------
# `compinit -C` skips compaudit, the check for world-writable or wrongly-owned
# directories in $fpath — and $fpath includes ~/.docker/completions above plus
# whatever Homebrew/Nix add. Completion files are sourced as zsh code at every
# shell start, so an insecure directory would load silently. Use a cached dump
# instead: still fast, still audited.
autoload -Uz compinit
ZCOMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump"
[ -d "${ZCOMPDUMP:h}" ] || mkdir -p "${ZCOMPDUMP:h}"
compinit -d "$ZCOMPDUMP"
zstyle ':completion:*' menu select

# -------------------------------------------------------------------
# SECTION: Load private functions & variables
# -------------------------------------------------------------------
[[ -f ~/.zshrc.private ]] && source ~/.zshrc.private

# -------------------------------------------------------------------
# SECTION: Aliases
# -------------------------------------------------------------------
[[ -f ~/.zshrc.alias ]] && source ~/.zshrc.alias
