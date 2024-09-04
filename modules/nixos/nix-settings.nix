{ lib, inputs, ... }:

{
  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
    # settings.auto-optimise-store = true;
    channel.enable = false; # only flakes :)

    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    registry = builtins.mapAttrs (_name: value: { flake = value; }) inputs;
    nixPath = [ "/etc/nix/path" ];
    settings.nix-path = "/etc/nix/path";
  };

  environment.etc = lib.mapAttrs' (name: value: lib.nameValuePair "nix/path/${name}" { source = value; }) inputs;
}
