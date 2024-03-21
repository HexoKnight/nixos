{ config, pkgs, inputs, unstable-overlay, config_name, ... }:

let
  username = "nixos";
in {
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-wsl.nixosModules.wsl
  ];
  nixpkgs.overlays = [ unstable-overlay ];

  wsl.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.channel.enable = false; # only flakes :)

  # allows 'normal' UNIX shebangs (eg. #!/bin/bash)
  # seems to fail on wsl (it uses a wierd file system or smthn)
  # services.envfs.enable = true;

  networking.hostName = "nixos";

  common-config = {
    host = {};
    users.${username} = {
      cansudo = true;
    };
  };

  # users.mutableUsers = false;

  wsl.defaultUser = username;
  users.users.${username} = {
    extraGroups = [ "wheel" ];

    packages = with pkgs; [
    ];
  };

  environment.variables = {
    # This is not very pure but only nixos-rebuild scripts depend on it
    # so they'll just fail harmlessly when run if there's nothing there.
    # To be entirely honest I'd rather this just be impure but oh well...
    NIXOS_BUILD_DIR = "/home/${username}/.nixos";
    NIXOS_BUILD_CONFIGURATION = config_name;
  };

  programs.ssh = {
    startAgent = true;
  };

  home-manager = {
    # extraSpecialArgs = {inherit inputs unstable-overlay;};
    # users.nixos = import "${inputs.self}/modules/home.nix";
  };

  environment.systemPackages = with pkgs; [
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
