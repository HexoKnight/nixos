{ ... }:

let
  username = "nixos";
in {
  imports = [
    ./hardware-configuration.nix
  ];

  wsl.enable = true;

  # allows 'normal' UNIX shebangs (eg. #!/bin/bash)
  # seems to fail on wsl (it uses a wierd file system or smthn)
  services.envfs.enable = false;

  setups = {
    config = {
      inherit username;
      hostname = "nixos";
    };
  };

  users.mutableUsers = true;

  wsl.defaultUser = username;

  programs.ssh = {
    startAgent = true;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
