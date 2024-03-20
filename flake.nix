{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/23.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dotfiles = {
      url = "git+ssh://git@github.com/HexoKnight/dotfiles";
      flake = false;
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, ... }@inputs:
    let
      system = "x86_64-linux";
      #pkgs = nixpkgs.legacyPackages.${system};
      unstable-overlay = final: prev: {
        unstable = nixpkgs-unstable.legacyPackages.${system};
      };
    in
    {
      nixosConfigurations = {
        default = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs unstable-overlay;
            config_name = "default";
          };
          modules = [
            { nixpkgs.overlays = [ unstable-overlay ]; }
            ./modules/internationalisation.nix
            ./modules/user-config.nix
            ./hosts/default/configuration.nix
          ];
        };
        wsl = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs unstable-overlay;
            config_name = "wsl";
          };
          modules = [
            { nixpkgs.overlays = [ unstable-overlay ]; }
            ./modules/internationalisation.nix
            ./modules/user-config.nix
            ./hosts/wsl/configuration.nix
          ];
        };
      };
    };
}
