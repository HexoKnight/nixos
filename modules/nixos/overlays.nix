{ lib, inputs, config, options, ... }:

let
  unstable-overlay = final: prev: {
    unstable = import config.unstable-overlay.source ({
      # passing config is not idempotent so this could
      # cause some issues but it seems fine for now
      inherit (final) system config;
    } // (config.unstable-overlay.extraArgs final prev));
  };
in
{
  options = {
    # exists so as to allow home manager to use the same (user specified) overlays
    # ie. use the original option for an overlay that shouldn't be used by home manager
    nixpkgs-overlays = options.nixpkgs.overlays;
    unstable-overlay = {
      enable = lib.mkEnableOption "the unstable overlay, available at `pkgs.unstable`";
      source = lib.mkOption {
        description = "The flake/package to use for the unstable pkgs";
        type = lib.types.package;
        default = inputs.nixpkgs-unstable;
      };
      extraArgs = lib.mkOption {
        description = "Function that takes the overlay args and produces extra args to pass when importing the unstable pkgs.";
        type = lib.types.functionTo (lib.types.functionTo lib.types.attrs);
        default = _final: _prev: {};
      };
    };
  };

  config = {
    nixpkgs-overlays = lib.mkIf config.unstable-overlay.enable [ unstable-overlay ];
    nixpkgs.overlays = config.nixpkgs-overlays;
  };
}
