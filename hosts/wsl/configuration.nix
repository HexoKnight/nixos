{ config, pkgs, inputs, unstable-overlay, config_name, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-wsl.nixosModules.wsl
  ];
  nixpkgs.overlays = [ unstable-overlay ];

  wsl.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.channel.enable = false; # only flakes :)

  # allows 'normal' UNIX shebangs (eg. #!/bin/bash)
  services.envfs.enable = true;

  networking.hostName = "nixos";

  users.mutableUsers = false;
  users.groups = {
    wheel = {};
    users = {};
  };

  wsl.defaultUser = "nixos";
  users.users.nixos = {
    extraGroups = [ "wheel" ];

    packages = with pkgs; [
      (writeShellScriptBin "rebuild" (builtins.readFile "${inputs.self}/rebuild.sh"))

      # required for the rebuild command
      (writeShellScriptBin "evalvar" (builtins.readFile "${inputs.self}/evalvar.sh"))
      unstable.nixVersions.nix_2_19
    ];
  };

  environment.variables = {
    # This is not very pure but only nixos-rebuild scripts depend on it
    # so they'll just fail harmlessly when run if there's nothing there.
    # To be entirely honest I'd rather this just be impure but oh well...
    NIXOS_BUILD_DIR = "/home/nixos/.nixos";
    NIXOS_BUILD_CONFIGURATION = config_name;
  };

  programs.ssh = {
    startAgent = true;
  };

  home-manager = {
    extraSpecialArgs = {inherit inputs unstable-overlay;};
    users.nixos = import "${inputs.self}/modules/home.nix";
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
