{ lib, ... }:

let
  username = "harvey";
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  setups = {
    config = {
      inherit username;
      hostname = "IDEAPAD";
      device = "/dev/sda";
    };
    impermanence = true;
    desktop = true;
  };

  services.tlp = {
    enable = true;
  };

  home-manager.users.${username} =
    { pkgs, ... }:
    {
      setups.tooling.jupyter.enable = true;
    };

  persist.defaultSetup = {
    swapSize = "4G";
    # prefer battery life over disk space
    btrfsCompression = "zstd:1";
  };
}
