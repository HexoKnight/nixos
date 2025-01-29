{
  imports = [
    ../generic

    ./grub-timestamp-format.nix
    ./overlays.nix
    ./syncthing.nix
    ./impermanence
    ./cloudflare-dns
    ./setups
  ];
}
