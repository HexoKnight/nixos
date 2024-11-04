{ pkgs, ... }:

{
  config = {
    services.nix-serve = {
      enable = true;
      package = pkgs.nix-serve-ng;

      port = 5000;
      openFirewall = true;
    };
  };
}
