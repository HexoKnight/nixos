{ lib, pkgs, config, ... }:

let
  username = "nixos";
in
{
  imports = [
    ./hardware-configuration.nix
    ./qbittorrent.nix
    ./nix-serve.nix

    ./cloudflare-dyndns.nix
    ./acme.nix
  ];

  lib.homeserver.environmentFileDir = "/root/envFiles";

  setups = {
    config = {
      inherit username;
      hostname = "HOMESERVER";
      device = "/dev/sda";
    };
    impermanence = true;
    minimal = true;
    sops = false;
  };

  boot.loader.timeout = 0;
  boot.loader.grub.useOSProber = lib.mkForce false;

  environment.systemPackages = [
    pkgs.kitty.terminfo
  ];

  security.sudo.wheelNeedsPassword = false;

  persist.system = {
    directories = [
      config.lib.homeserver.environmentFileDir
      "/etc/ssh"
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  users.users.${username}.openssh = {
    authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA31Hyz+ojGgqFBK76xDZMrAUvRUaPkw76OyNKBoViGd"
    ];
  };
}
