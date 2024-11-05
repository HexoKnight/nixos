{ config, ... }:

{
  config = {
    acme.users.bruhpi = [ config.services.nginx.user ];

    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      virtualHosts."cache.bruhpi.uk" =  {
        addSSL = true;
        useACMEHost = "bruhpi.uk";

        locations."/" = {
          proxyPass = "http://127.0.0.1:5000";
        };
      };

      virtualHosts."qbittorrent.bruhpi.uk" =  {
        addSSL = true;
        useACMEHost = "bruhpi.uk";

        locations."/" = {
          proxyPass = "https://127.0.0.1:8080";
        };
      };
    };
  };
}
