{
  lib,
  pkgs,
  config,
  ...
}:

let
  username = "nixos";
in
{
  imports = [
    ./hardware-configuration.nix

    ./nginx.nix
    ./qbittorrent.nix
    ./nix-serve.nix
    ./project-zomboid
    ./bruh-bot
    ./minecraft
    ./factorio

    ./cloudflare-dns.nix
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

  disko = (import ./disko.nix).disko;

  home-manager.users.${username} = {
    setups.normal = true;
  };

  # no timeout makes it next to impossible to rollback
  boot.loader.timeout = 1;
  boot.loader.grub.useOSProber = lib.mkForce false;

  environment.systemPackages = [
    pkgs.kitty.terminfo
  ];

  security.sudo.wheelNeedsPassword = false;
  security.polkit = {
    enable = true;
    extraConfig = /* js */ ''
      polkit.addRule(function(action, subject) {
        if (subject.isInGroup("wheel")) {
          return polkit.Result.YES
        }
      })
    '';
  };

  persist.system = {
    directories = [
      config.lib.homeserver.environmentFileDir
      "/etc/ssh"
    ];
  };

  # one of a few workarounds for impermanence creating `/persist/var/lib/private` with 755 instead of 700
  # see: https://github.com/nix-community/impermanence/issues/254
  system.activationScripts."createPersistentStorageDirs".deps = [ "var-lib-private-permissions" ];
  system.activationScripts."var-lib-private-permissions" = {
    deps = [ "specialfs" ];
    text = ''
      mkdir -p ${config.persist.root}/system/var/lib/private
      chmod 0700 ${config.persist.root}/system/var/lib/private
    '';
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
  dnsRecords.ssh.record = {
    type = "CNAME";
    name = "ssh";
    content = "raw.@";
    proxied = false;
  };

  users.users.${username}.openssh = {
    authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA31Hyz+ojGgqFBK76xDZMrAUvRUaPkw76OyNKBoViGd"
    ];
  };
}
