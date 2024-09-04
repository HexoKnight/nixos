{ lib, inputs, local-pkgs }:

configurations:
extraModules:

lib.mapAttrs (config_name: extraOptions: lib.nixosSystem (
  {
    specialArgs = {
      inherit inputs local-pkgs config_name;
    };
    modules = [
      ./${config_name}
      ../modules/nixos
    ] ++ extraModules;
  }
  // extraOptions
)) configurations
