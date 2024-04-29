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

  host-config.disable-touchpad = "elan1205:00-04f3:30e9-touchpad";

  fileSystems."/c:" = {
    device = "/dev/nvme0n1p3";
    fsType = "ntfs3";
    options = [ "nofail" ];
  };
}
