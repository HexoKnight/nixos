{ ... }:

let
  username = "harvey";
in
{
  imports = [
    ./hardware-configuration.nix
    (import ../generic/desktop {
      inherit username;
      hostName = "IDEAPAD";
      device = "/dev/sda";
      dual-boot = true;
      impermanence = true;
    })
  ];

  services.tlp = {
    enable = true;
  };

  persist.defaultSetup.swapSize = "4G";
}
