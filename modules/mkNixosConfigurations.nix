{ lib, inputs, local-pkgs }:

configurations:
extraModules:

lib.mapAttrs (config_name: extraOptions: lib.nixosSystem (
  {
    specialArgs = {
      inherit inputs local-pkgs config_name;
    };
    modules = [
      ../configurations/${config_name}/configuration.nix
      ./misc
    ] ++ extraModules;
  }
  // extraOptions
)) configurations
