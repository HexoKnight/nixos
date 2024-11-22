{ lib, inputs }:

configurations:
extraModules:

lib.mapAttrs (config_name: extraOptions: lib.nixosSystem (
  {
    specialArgs = {
      inherit inputs;
    };
    modules = [
      ./${config_name}
      ../modules/nixos
      {
        _module.args = {
          inherit config_name;
        };
      }
    ] ++ extraModules;
  }
  // extraOptions
)) configurations
