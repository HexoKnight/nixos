{
  imports = [
    ../generic

    ./internationalisation.nix
    ./host-config.nix
    ./userhome-config.nix
    ./grub-timestamp-format.nix
    ./overlays.nix
    ./nix-settings.nix
    ./syncthing.nix
    ./impermanence
  ];
}
