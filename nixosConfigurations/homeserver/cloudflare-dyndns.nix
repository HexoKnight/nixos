{ config, ... }:

{
  config = {
    services.cloudflare-dyndns = {
      enable = true;

      ipv4 = true;
      ipv6 = true;
      proxied = true;

      domains = [ "bruhpi.uk" "*.bruhpi.uk" ];

      # location of CLOUDFLARE_API_TOKEN=[value]
      # https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#EnvironmentFile=
      apiTokenFile = "${config.lib.homeserver.environmentFileDir}/CLOUDFLARE_API_TOKEN";
    };
  };
}
