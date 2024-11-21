{ lib, inputs, config, ... }:

let
  cfg = config.setups.nix;
in
{
  options.setups.nix = {
    flakes = {
      enable = lib.mkEnableOption "flakes and disable channels";
      inputs = {
        provideInFlakeRegistry = lib.mkOption {
          description = "Whether to expose flake inputs in the registry";
          type = lib.types.bool;
          default = true;
        };
        provideInNixPath = lib.mkOption {
          description = "Whether to expose flake inputs in nix-path at /etc/nix/path";
          type = lib.types.bool;
          default = true;
        };
      };
    };
    autoclean.enable = lib.mkEnableOption "weekly store optimisation and gc";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.flakes.enable (lib.mkMerge [
      {
        nix.settings.experimental-features = [ "nix-command" "flakes" ];
        nix.channel.enable = false; # only flakes :)
      }
      (lib.mkIf cfg.flakes.inputs.provideInFlakeRegistry {
        nix.registry = builtins.mapAttrs (_name: value: { flake = value; }) inputs;
      })
      (lib.mkIf cfg.flakes.inputs.provideInNixPath {
        nix.nixPath = [ "/etc/nix/path" ];
        nix.settings.nix-path = "/etc/nix/path";

        environment.etc = lib.mapAttrs' (name: value: lib.nameValuePair "nix/path/${name}" { source = value; }) inputs;
      })
    ]))
    (lib.mkIf cfg.autoclean.enable {
      nix.optimise = {
        automatic = true;
        dates = [ "weekly" ];
      };
      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 14d";
      };
    })
  ];
}
