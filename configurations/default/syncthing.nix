{ username }:

{ config, pkgs, inputs, ... }:

{
  services.syncthing = {
    enable = true;
    user = username;
    dataDir = "/home/${username}";
    configDir = "/home/${username}/.config/syncthing";
    overrideDevices = true;
    overrideFolders = true;
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
