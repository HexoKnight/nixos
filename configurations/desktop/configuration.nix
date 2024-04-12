{ config, lib, pkgs, inputs, config_name, ... }:

{
  imports = [
    ./hardware-configuration.nix
    (import ../../modules/desktop/configuration.nix {
      username = "harvey";
      hostName = "HARVEY-nixos";
      device = "/dev/sda";
      impermanence = true;
    })
  ];

  networking.interfaces.eno1.wakeOnLan = {
    enable = true;
    policy = [ "magic" ];
  };
}
