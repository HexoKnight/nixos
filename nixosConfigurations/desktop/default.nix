{ config, lib, pkgs, inputs, config_name, ... }:

let
  username = "harvey";
in
{
  imports = [
    ./hardware-configuration.nix
    (import ../generic/desktop {
      inherit username;
      hostName = "HARVEY-nixos";
      device = "/dev/sda";
      impermanence = true;
      personal-gaming = true;
    })
  ];

  networking.interfaces.eno1.wakeOnLan = {
    enable = true;
    policy = [ "magic" ];
  };

  syncthing = {
    enable = true;
    inherit username;
    settings = {
      devices.HARVEY.id = "6BX7VGF-BHSJAFI-BDU3QAF-GNPQPGO-PRUAIZK-CDSL3HA-GWXY6EX-FI74TAU";
      folders = {
        Vencord = {
          id = "vencord_config";
          path = "/home/${username}/.config/Vencord";
          devices = [ "HARVEY" ];
        };
      };
    };
  };
}
