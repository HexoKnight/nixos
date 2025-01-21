{ lib, config, options, ... }:

{
  options = {
    dnsRecords = lib.mkOption {
      description = "DNS records to be updated.";
      type = (options.services.cloudflare-dns.domains.type.getSubOptions []).dnsRecords.type;
      default = {};
    };
  };

  config = {
    services.cloudflare-dns = {
      enable = true;
      # location of CLOUDFLARE_API_TOKEN=[value]
      apiTokenFile = "${config.lib.homeserver.environmentFileDir}/CLOUDFLARE_API_TOKEN";

      domains."bruhpi.uk" = {
        dnsRecords = config.dnsRecords;
      };
    };
  };
}
