{ self, nixpkgs, ... }@inputs:

configurations:
extraModules:

let
  lib = nixpkgs.lib.extend (final: _prev: import (self + /lib) final);
in
lib.mapAttrs (config_name: extraOptions: lib.nixosSystem (
  {
    specialArgs = {
      inherit inputs config_name lib;
    };
    modules = [
      ../configurations/${config_name}/configuration.nix
      ./misc
    ] ++ extraModules;
  }
  // extraOptions
)) configurations
