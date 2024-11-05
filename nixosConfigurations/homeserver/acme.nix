{ lib, config, ... }:

let
  cfg = config.acme;
in
{
  options.acme = {
    users = {
      bruhpi = lib.mkOption {
        description = "users that can access the bruhpi.uk certificate";
        type = lib.types.listOf lib.types.str;
        default = [];
      };
    };
  };

  config = {
    persist.system = {
      directories = [
        "/var/lib/acme"
      ];
    };

    users.groups."acme-bruhpi".members = cfg.users.bruhpi;

    security.acme = {
      acceptTerms = true;
      defaults.email = "harvey.gream@gmail.com";
      certs = {
        "bruhpi.uk" = {
          extraDomainNames = [ "*.bruhpi.uk" ];
          dnsProvider = "cloudflare";
          group = "acme-bruhpi";
          # location of CLOUDFLARE_DNS_API_TOKEN=[value]
          # https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#EnvironmentFile=
          environmentFile = "${config.lib.homeserver.environmentFileDir}/CLOUDFLARE_DNS_API_TOKEN";
        };
      };
    };
  };
}
