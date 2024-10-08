{ lib, options, config, inputs, local-pkgs, ... }:

let
  unstable-overlay = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final) system config;
      overlays = [
        (_final-unstable: _prev-unstable: {
          # TODO: move elsewhere
          xwayland = final.xwayland;
        })
      ];
    };
  };
  local-overlay = final: _prev: {
    local = local-pkgs final;
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
