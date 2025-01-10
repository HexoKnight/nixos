{
  description = "Nixos config flake";

  inputs = {
    # main nixpkgs stuff
    nixpkgs.url = "github:nixos/nixpkgs/release-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixos module sorta things
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # home manager stuff
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # homeserver specific
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # external package repos
    # hyprland = {
    #   url = "github:hyprwm/Hyprland/v0.39.0";
    #   # maybe when nixpgs is updated but rn it's too out of date
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    # hyprland-plugins = {
    #   url = "github:hyprwm/hyprland-plugins";
    #   inputs.hyprland.follows = "hyprland";
    # };
    # hycov = {
    #   url = "github:DreamMaoMao/hycov/0.39.0.1";
    #   inputs.hyprland.follows = "hyprland";
    # };

    # nixos hardware stuff
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, ... }@inputs:
  let
    lib = nixpkgs.lib.extend (final: _prev: import ./lib final);
    local-pkgs = pkgs:
      let args = { inherit lib pkgs; }; in
      import ./packages args //
      import ./scripts args;

    mkNixosConfigurations = import ./nixosConfigurations/mkNixosConfigurations.nix { inherit inputs lib; };
    forAllSystems = lib.genAttrs lib.systems.flakeExposed;
  in
  {
    nixosConfigurations = mkNixosConfigurations {
      desktop = {};
      homeserver = {
        extraModules = [
          inputs.nix-minecraft.nixosModules.minecraft-servers
        ];
      };
      main-machine = {
        extraModules = [
          inputs.nixos-hardware.nixosModules.asus-zephyrus-ga502
        ];
      };
      weak-machine = {};
      wsl = {
        extraModules = [
          inputs.nixos-wsl.nixosModules.wsl
        ];
      };
    } [
      {
        imports = [
          inputs.home-manager.nixosModules.home-manager

          inputs.sops-nix.nixosModules.sops
          inputs.impermanence.nixosModules.impermanence
          inputs.disko.nixosModules.disko
        ];

        home-manager.sharedModules = [
          inputs.nix-index-database.hmModules.nix-index
          inputs.plasma-manager.homeManagerModules.plasma-manager
        ];

        nixpkgs-overlays = [
          (final: _prev: {
            local = local-pkgs final;
          })
        ];
      }
    ];

    lib = import ./lib lib;

    packages = forAllSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      local-pkgs pkgs
    );
  };
}
