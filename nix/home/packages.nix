# Non-dev CLI packages (see README's Nix + asdf exceptions table for GUI apps
# that stay outside Nix, e.g. Ghostty, Helium, Zed).
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Core CLI utils
    bat
    curl
    direnv
    eza
    fzf
    gh
    git
    git-filter-repo
    gnupg
    gojq
    jq
    neovim
    rsync
    starship
    tmux
    unzip
    yq
    zip
    zoxide

    # Cloud CLIs
    awscli2
    azure-cli
    azurite
    google-cloud-sdk

    # AI Harness CLIs
    claude-code
    codex
    opencode

    # Version managers (asdf, uv)
    asdf-vm
    uv
  ];
}
