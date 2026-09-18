# Ubuntu Nerd Fonts, home-manager equivalent of nix-darwin's
# `fonts.packages` (darwin/configuration.nix). Not imported into ./home.nix
# (shared) — wired directly into the `<user>@ubuntu` homeConfiguration in
# ../flake.nix so macOS (still on nix-darwin's own font module) is unaffected.
{ pkgs, ... }:

{
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    nerd-fonts.inconsolata
  ];
}
