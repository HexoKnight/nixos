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
  };
  config = {
    users.mutableUsers = cfg.mutableUsers;
  };
}
