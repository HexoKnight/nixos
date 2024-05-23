{ inputs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # nix.settings.auto-optimise-store = true;
  nix.channel.enable = false; # only flakes :)

  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.registry = builtins.mapAttrs (_name: value: { flake = value; }) inputs;
}
