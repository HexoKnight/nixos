{ lib, config, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ./no-specialisation.nix
    ./guest-specialisation.nix
  ];

  setups = {
    config = {
      hostname = "IDEAPAD";
      device = "/dev/sda";
    };
  };

  services.tlp = lib.mkIf (!config.services.power-profiles-daemon.enable) {
    enable = true;
  };

  persist.defaultSetup = {
    swapSize = "4G";
    # prefer battery life over disk space
    btrfsCompression = "zstd:1";
  };
}
