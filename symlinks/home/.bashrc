# ~/.bashrc — Cross-platform (macOS + Linux), translated from ~/.zshrc.
# Executed by bash(1) for non-login shells. Login shells reach this via
# ~/.profile sourcing it (see ~/.profile: `[ -n "$BASH_VERSION" ] && . ~/.bashrc`).

# If not running interactively, don't do anything.
case $- in
    *i*) ;;
      *) return;;
esac

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
# zsh's APPEND_HISTORY -> bash's histappend.
HISTSIZE=9999
HISTFILESIZE=999999
shopt -s histappend
# zsh's HIST_IGNORE_DUPS -> ignoredups; keep leading-space-hidden commands too (ignoreboth).
HISTCONTROL=ignoreboth
# zsh's SHARE_HISTORY has no direct bash equivalent; approximate real-time sharing
# across sessions by appending/reloading history around every prompt.
PROMPT_COMMAND="history -a; history -c; history -r${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
# check the window size after each command and, if necessary, update LINES/COLUMNS.
shopt -s checkwinsize

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
# SECTION: Prompt
# -------------------------------------------------------------------
# Oh My Zsh + Powerlevel10k (~/.zshrc) are zsh-only — no bash port. Fall back to
# bash's own colored prompt instead.
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# -------------------------------------------------------------------
# SECTION: FZF key bindings & completion
# -------------------------------------------------------------------
if command -v fzf >/dev/null 2>&1; then
    [ -f ~/.fzf.bash ] && source ~/.fzf.bash || eval "$(fzf --bash)"
fi
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"

# -------------------------------------------------------------------
# SECTION: Zoxide
# -------------------------------------------------------------------
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init --cmd cd bash)"
fi

# -------------------------------------------------------------------
# SECTION: Docker completions
# -------------------------------------------------------------------
# zsh's ~/.zshrc adds this dir to $fpath; bash completion scripts must be sourced
# individually instead.
if [ -d ~/.docker/completions ]; then
    for f in ~/.docker/completions/*; do
        [ -f "$f" ] && source "$f"
    done
fi

# -------------------------------------------------------------------
# SECTION: PATH hygiene
# -------------------------------------------------------------------
# zsh's `typeset -U PATH` dedupes in place; bash has no builtin equivalent, so
# rebuild PATH dropping repeated entries while preserving order.
PATH="$(printf '%s' "$PATH" | awk -v RS=: '!seen[$0]++ { printf "%s%s", sep, $0; sep=":" }')"
export PATH

# -------------------------------------------------------------------
# SECTION: Initialize completions
# -------------------------------------------------------------------
# enable programmable completion features (you don't need to enable this, if
# it's already enabled in /etc/bash.bashrc and /etc/profile sources it).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  elif [ -f /opt/homebrew/etc/profile.d/bash_completion.sh ]; then
    . /opt/homebrew/etc/profile.d/bash_completion.sh
  fi
fi

# -------------------------------------------------------------------
# SECTION: Load private functions & variables
# -------------------------------------------------------------------
[ -f ~/.bashrc.private ] && . ~/.bashrc.private

# -------------------------------------------------------------------
# SECTION: Aliases
# -------------------------------------------------------------------
# Additions go in ~/.bashrc.alias, matching this file's own convention.
[ -f ~/.bashrc.alias ] && . ~/.bashrc.alias
