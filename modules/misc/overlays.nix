{ options, config, inputs, ... }:

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
in
{
  options.nixpkgs-overlays =
    options.nixpkgs.overlays;

  config = {
    nixpkgs-overlays = [ unstable-overlay ];
    nixpkgs.overlays = config.nixpkgs-overlays;
  };
}
