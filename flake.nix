{
  description = "Nixos config flake";

  inputs = {
    # main nixpkgs stuff
    nixpkgs.url = "github:nixos/nixpkgs/release-24.05";
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
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:pjones/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
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

    mkNixosConfigurations = import ./nixosConfigurations/mkNixosConfigurations.nix { inherit inputs lib local-pkgs; };
    forAllSystems = lib.genAttrs lib.systems.flakeExposed;
  in
  {
    nixosConfigurations = mkNixosConfigurations {
      desktop = {};
      homeserver = {};
      dual-boot = {};
      mobile-dual-boot = {};
      wsl = {};
    } [
      {
        # nix.settings = {
        #   substituters = ["https://hyprland.cachix.org"];
        #   trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
        # };
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
