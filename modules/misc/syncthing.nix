{ lib, pkgs, config, options, inputs, ... }:

with lib;
let
  cfg = config.syncthing;
  inherit (cfg) username;
in
{
  options.syncthing = {
    enable = mkEnableOption "syncthing";
    username = mkOption {
      description = "the user whose home will hold syncthing data";
      type = types.str;
    };
    settings = (import (inputs.nixpkgs + /nixos/modules/services/networking/syncthing.nix) {inherit options config pkgs lib;}).options.services.syncthing.settings;
  };
  config = mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      user = username;
      dataDir = "/home/${username}/Documents/syncthing";
      configDir = "/home/${username}/.config/syncthing";
      overrideDevices = true;
      overrideFolders = true;
      inherit (cfg) settings;
    };
  };
}
