{ lib, config, inputs, ... }:

let
  cfg = config.persist-home;

  inherit (lib) mkEnableOption mkOption types;

  persistence-options = (import "${inputs.self}/modules/lib/impermanence.nix" { inherit lib; }).override (final: prev: {
    # TODO: add extensions
  });
in
{
  options.persist-home = {
    enable = mkEnableOption "home persistence (requires the OS, ie. cannot be used in standalone home-manager)";

    inherit (persistence-options) directories files;

    usedByOS = mkOption {
      type = types.bool;
      default = false;
      internal = true;
    };
  };

  config = {
    assertions = lib.singleton {
      assertion = cfg.enable -> cfg.usedByOS;
      message = ''
        Home persistence (persist-home) is enabled but the OS is not using it.
        This could be due to home-manager being used outside of NixOS
        or the NixOS setup not enabling the 'persist' module.
        Either disable home persistence or fix the OS configuration.
      '';
    };
  };
}
