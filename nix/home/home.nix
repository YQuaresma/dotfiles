# Shared home-manager config, both OSes.
# Phase 3 fills in ./packages.nix and ./zsh.nix, imported below.
{ pkgs, ... }:

{
  imports = [
    ./packages.nix
    ./zsh.nix
  ];

  # Bump only on deliberate upgrade after reading the home-manager release notes.
  home.stateVersion = "24.11";

  # allowUnfree (needed later for claude-code, Phase 3.6) is set at the system/global
  # pkgs level (darwin/configuration.nix, flake.nix ubuntu import) — NOT here, since
  # `nixpkgs.config` conflicts with `home-manager.useGlobalPkgs` on macOS.
}
