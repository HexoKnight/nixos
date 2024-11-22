{ lib, inputs, local-pkgs }:

configurations:
extraModules:

lib.mapAttrs (config_name: extraOptions: lib.nixosSystem (
  {
    specialArgs = {
      inherit inputs config_name;
    };
    modules = [
      ./${config_name}
      ../modules/nixos
      {
        nixpkgs-overlays = [
          (final: _prev: {
            local = local-pkgs final;
          })
        ];
      }
    ] ++ extraModules;
  }
  // extraOptions
)) configurations
