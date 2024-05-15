{ inputs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.channel.enable = false; # only flakes :)

  nix.registry = builtins.mapAttrs (_name: value: { flake = value; }) inputs;
}
