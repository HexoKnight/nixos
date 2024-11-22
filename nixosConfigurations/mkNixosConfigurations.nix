{ lib, inputs }:

configurations:
extraModules:

lib.mapAttrs (config_name: extraOptions: lib.nixosSystem (
  {
    modules = [
      ./${config_name}
      ../modules/nixos
      {
        _module.args = {
          inherit config_name inputs;
        };
      }
    ] ++ extraModules;
  }
  // extraOptions
)) configurations
