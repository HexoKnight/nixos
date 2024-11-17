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
      extraUserOptions = {
        description = "Harvey Gream";
      };
    };
    impermanence = true;
    desktop = true;
  };

  services.tlp = {
    enable = true;
  };

  userhome-config.${username}.extraHmModules = lib.singleton (
    { pkgs, ... }:
    {
      nixpkgs.allowUnfreePkgs = [
        "visual-paradigm"
        "idea-ultimate"
      ];

      home.packages = [
        pkgs.local.visual-paradigm
        pkgs.jetbrains.idea-ultimate
      ];
      persist-home = {
        directories = [
          ".config/VisualParadigm"

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

      setups.jupyter.enable = true;
    }
  );

  persist.defaultSetup = {
    swapSize = "4G";
    # prefer battery life over disk space
    btrfsCompression = null;
  };
}
