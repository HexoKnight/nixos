{ lib, options, config, inputs, ... }:

let
  unstable-overlay = final: prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (prev) system config;
      overlays = [
        (final-unstable: prev-unstable: {
          # TODO: move elsewhere
          xwayland = prev.xwayland;
        })
      ];
    };
  };
  local-overlay = final: prev: {
    local = import "${inputs.self}/packages" {
      inherit (prev) system;
      inherit lib;
      pkgs = prev;
    };
  };
in
{
  options.nixpkgs-overlays =
    options.nixpkgs.overlays;

  config = {
    nixpkgs-overlays = [ unstable-overlay local-overlay ];
    nixpkgs.overlays = config.nixpkgs-overlays;
  };
}
