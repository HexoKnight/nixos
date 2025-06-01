{ config, ... }:

{
  config = {
    services.cloudflare-dyndns = {
      enable = true;

      ipv4 = true;
      ipv6 = true;
      proxied = false;

      domains = [ "raw.bruhpi.uk" ];

      apiTokenFile = "${config.lib.homeserver.environmentFileDir}/CLOUDFLARE_API_TOKEN";
    };
  };
}
