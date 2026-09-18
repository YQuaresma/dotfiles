# macOS system config (nix-darwin). Manages: Nix daemon opt-out, unfree flag, primary
# user, and fonts (was install-fonts.sh). No `defaults write`/Homebrew
# integration yet.
# `user` comes from flake.nix's specialArgs — the single place the account name
# is configured; do not hardcode it here.
{ pkgs, user, ... }:

{
  # Determinate Nix already manages the daemon/store — let nix-darwin manage config,
  # not the Nix installation itself (avoids the two installers fighting over
  # /etc/nix/nix.conf and the daemon plist).
  nix.enable = false;

  nixpkgs.config.allowUnfree = true; # needed later for claude-code (Phase 3.6)

  system.primaryUser = user;

  users.users.${user}.home = "/Users/${user}";

  # 3.3 — Nerd Fonts (was install-fonts.sh's brew-cask block)
  fonts.packages = with pkgs; [
    nerd-fonts.inconsolata
  ];

  # Bump only on deliberate upgrade after reading the nix-darwin release notes.
  system.stateVersion = 5;
}
