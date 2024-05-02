{ config, options, pkgs, lib, inputs, unstable-overlay, ... }:

with lib;
let
  cfg = config.host-config;
in {
  options.host-config = {
    mutableUsers = mkOption {
      default = true;
      description = "literally just users.mutableUsers";
      type = types.bool;
    };
    desktop = mkOption {
      default = false;
      description = "whether the host has a desktop";
      type = types.bool;
    };
    disable-touchpad = mkOption {
      default = null;
      description = "the name (`hyprctl devices | grep touchpad`) of the touchpad to disable";
      type = types.nullOr types.str;
    };
  };
  config = {
    users.mutableUsers = cfg.mutableUsers;
  };
}
