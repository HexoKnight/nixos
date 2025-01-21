{
  imports = [
    ../generic

    ./userhome-config.nix
    ./grub-timestamp-format.nix
    ./overlays.nix
    ./syncthing.nix
    ./impermanence
    ./cloudflare-dns
    ./setups
  ];
}
