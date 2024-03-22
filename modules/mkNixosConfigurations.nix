{ self, nixpkgs, nixpkgs-unstable, ... }@inputs:

configurations:

let
  system = "x86_64-linux";
  unstable-overlay = final: prev: {
    unstable = nixpkgs-unstable.legacyPackages.${system};
  };
in
nixpkgs.lib.attrsets.mapAttrs (config_name: extraOptions: nixpkgs.lib.nixosSystem (
  {
    specialArgs = {
      inherit inputs unstable-overlay config_name;
    };
    modules = [
      { nixpkgs.overlays = [ unstable-overlay ]; }
      ../configurations/${config_name}/configuration.nix
      ./internationalisation.nix
      ./userhome-config.nix
    ];
  }
  // extraOptions
)) configurations
