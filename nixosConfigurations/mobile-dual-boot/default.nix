{ lib, ... }:

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

  userhome-config.${username}.extraHmModules = lib.singleton (
    { pkgs, ... }:
    {
      nixpkgs.allowUnfreePkgs = [
        "idea-ultimate"
      ];

      home.packages = [
        pkgs.mysql-workbench
        pkgs.jetbrains.idea-ultimate
      ];
      persist-home = {
        directories = [
          # mysql-workbench
          ".mysql"

          # jetbrains.idea-ultimate
          ".cache/JetBrains"
          ".config/JetBrains"
          ".local/share/JetBrains"
          # I hate that this is generated
          # afaict it isn't actually required
          # but just in case :/
          ".java"
        ];
      };

      jupyter.enable = true;
    }
  );

  persist.defaultSetup = {
    swapSize = "4G";
    # prefer battery life over disk space
    btrfsCompression = null;
  };
}
