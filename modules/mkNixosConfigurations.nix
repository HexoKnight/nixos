{ self, nixpkgs, ... }@inputs:

configurations:
extraModules:

nixpkgs.lib.attrsets.mapAttrs (config_name: extraOptions: nixpkgs.lib.nixosSystem (
  {
    specialArgs = {
      inherit inputs config_name;
    };
    modules = [
      ../configurations/${config_name}/configuration.nix
      ./misc
    ] ++ extraModules;
  }
  // extraOptions
)) configurations
