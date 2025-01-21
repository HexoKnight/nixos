{ lib, config, ... }:

let
  cfg = config.acme;
in
{
  options.acme = {
    users = lib.mapAttrs (domain: _:
      lib.mkOption {
        description = "Users that can access the ${domain} certificate.";
        type = lib.types.listOf lib.types.str;
        default = [];
      }
    ) config.security.acme.certs;
  };

  config = {
    persist.system = {
      directories = [
        "/var/lib/acme"
      ];
    };

    users.groups = lib.mapAttrs' (domain: config:
      lib.nameValuePair config.group {
        members = cfg.users.${domain};
      }
    ) config.security.acme.certs;

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
