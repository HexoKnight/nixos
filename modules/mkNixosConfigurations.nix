{ self, nixpkgs, nixpkgs-unstable, ... }@inputs:

configurations:
extraModules:

let
  unstable-overlay = final: prev: {
    unstable = nixpkgs-unstable.legacyPackages.${prev.system};
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
      ./misc
    ] ++ extraModules;
  }
  // extraOptions
)) configurations
