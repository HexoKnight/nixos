{ self, nixpkgs, nixpkgs-unstable, ... }@inputs:

configurations:

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
      ./internationalisation.nix
      ./host-config.nix
      ./userhome-config.nix
    ];
  }
  // extraOptions
)) configurations
