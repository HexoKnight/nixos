{
  imports = [
    ../generic

    ./userhome-config.nix
    ./grub-timestamp-format.nix
    ./overlays.nix
    ./nix-settings.nix
    ./syncthing.nix
    ./impermanence
    ./setups
  ];
}
