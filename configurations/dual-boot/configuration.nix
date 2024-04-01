{ config, lib, pkgs, inputs, config_name, ... }:

{
  imports = [
    ./hardware-configuration.nix
    (import ../../modules/desktop/configuration.nix {
      username = "harvey";
      hostName = "HARVEY";
      device = "/dev/nvme0n1";
      dual-boot = true;
      impermanence = true;
    })
  ];

  fileSystems."/windows" = {
    device = "/dev/nvme0n1p3";
    fsType = "ntfs3";
  };
}
