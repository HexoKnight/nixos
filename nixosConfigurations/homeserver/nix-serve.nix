{ pkgs, ... }:

{
  config = {
    services.nix-serve = {
      enable = true;
      package = pkgs.nix-serve-ng;

      port = 5000;
      openFirewall = true;
    };

    nginx.hosts.cache = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:5000";
      };
    };
  };
}
