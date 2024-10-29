{ pkgs, ... }:

let
  username = "nixos";
in
{
  imports = [
    ./hardware-configuration.nix
  ];

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

  environment.systemPackages = [
    pkgs.kitty.terminfo
  ];

  security.sudo.wheelNeedsPassword = false;

  persist.system = {
    directories = [
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
