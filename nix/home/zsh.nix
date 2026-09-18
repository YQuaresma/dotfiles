# oh-my-zsh core, powerlevel10k theme, zsh-autosuggestions and
# zsh-syntax-highlighting plugins, provisioned from the Nix store instead of
# install-ohmyzsh.sh's git clones.
#
# Deliberately does NOT use home-manager's `programs.zsh` (would generate ~/.zshrc
# and conflict with the existing symlinks/home-managed, hand-written one). Instead: symlink
# the read-only packages into place, and ~/.zshrc gets exactly one added line
# (`export ZSH_CUSTOM=...`) so oh-my-zsh's loader finds the custom theme/plugins
# outside the read-only $ZSH tree. See flake home.file targets below.
{ pkgs, ... }:

{
  home.file = {
    # $ZSH itself — oh-my-zsh core (oh-my-zsh.sh, lib/, built-in plugins/themes).
    # Read-only, but oh-my-zsh.sh auto-falls-back its cache dir to
    # ~/.cache/oh-my-zsh when $ZSH/cache isn't writable — no further config needed.
    ".oh-my-zsh".source = "${pkgs.oh-my-zsh}/share/oh-my-zsh";

    # $ZSH_CUSTOM — kept OUTSIDE the read-only .oh-my-zsh symlink (can't nest a
    # writable-looking path inside one), pointed at by the added .zshrc export.
    ".oh-my-zsh-custom/themes/powerlevel10k".source = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k";
    ".oh-my-zsh-custom/plugins/zsh-autosuggestions".source = "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions";
    ".oh-my-zsh-custom/plugins/zsh-syntax-highlighting".source = "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting";
  };
}
