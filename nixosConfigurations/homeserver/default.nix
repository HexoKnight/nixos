{ ... }:

let
  username = "nixos";
in
{
  imports = [
    ./hardware-configuration.nix
    (import ../generic/desktop {
      inherit username;
      hostName = "HOMESERVER";
      device = "/dev/sda";
      impermanence = true;
    })
  ];

  persist.system = {
    directories = [
      "/etc/ssh"
    ];
  };

  services.openssh = {
    enable = true;
  };

  users.users.${username}.openssh = {
    authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA31Hyz+ojGgqFBK76xDZMrAUvRUaPkw76OyNKBoViGd"
    ];
  };
}
