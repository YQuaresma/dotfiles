{
  description = "Nix + home-manager (+ nix-darwin on macOS) config";

  inputs = {
    # Pinned to a specific nixos-unstable commit (not the moving branch ref)
    # because a later revision ships asdf-vm 0.20.1, whose upstream GitHub
    # release tag was deleted (NixOS/nixpkgs#566395), 404ing the source fetch.
    # Bump back to "github:NixOS/nixpkgs/nixos-unstable" once nixpkgs#566396
    # (asdf-vm 0.20.1 -> 0.20.2) merges.
    nixpkgs.url = "github:NixOS/nixpkgs/7a530b8a08ee144c40d90e60bbcf541b9bf10aa6";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-darwin, ... }:
    let
      # The one place the local account name is configured. Forking this repo?
      # Change these two values and nothing else — every module below, including
      # darwin/configuration.nix (via specialArgs), reads them from here.
      user = "babilonia";
      hostName = "MacbookAir";
    in
    {
      # Ubuntu: `home-manager switch --flake ~/.dotfiles/nix#<user>@ubuntu`
      homeConfigurations."${user}@ubuntu" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true; # needed later for claude-code (Phase 3.6)
        };
        modules = [ ./home/home.nix ./home/fonts-linux.nix { programs.home-manager.enable = true; home.username = user; home.homeDirectory = "/home/${user}"; } ];
      };

      # macOS: `sudo darwin-rebuild switch --flake ~/.dotfiles/nix#<hostName>`
      darwinConfigurations."${hostName}" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit user; };
        modules = [
          ./darwin/configuration.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users."${user}" = { ... }: {
              imports = [ ./home/home.nix ];
              home.username = user;
              home.homeDirectory = "/Users/${user}";
            };
          }
        ];
      };
    };
}
