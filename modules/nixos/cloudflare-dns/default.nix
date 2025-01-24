{ lib, pkgs, config, ... }:

let
  cfg = config.services.cloudflare-dns;

  inherit (lib) types;

  # https://developers.cloudflare.com/api/resources/dns/subresources/records/models/record/#(schema)
  recordType = (pkgs.formats.json {}).type;

  domainSubmodule = {name, ...}: {
    options = {
      enable = lib.mkEnableOption "updating DNS records for this domain" // { default = true; };
      dnsRecords = lib.mkOption {
        description = "DNS records to be updated.";
        type = types.attrsOf (types.submodule dnsRecordSubmodule);
        default = {};
      };
    };
  };

  dnsRecordSubmodule = {name, ...}: {
    options = {
      enable = lib.mkEnableOption "this DNS record (disabling/removing this later will delete this record)" // { default = true; };
      updateOnly = lib.mkOption {
        description = "Try to update this record instead of overwriting it.";
        type = types.bool;
        default = false;
      };
      record = lib.mkOption {
        description = ''
          JSON representation of the dns record.
          see: https://developers.cloudflare.com/api/resources/dns/subresources/records/models/record/#(schema)
        '';
        type = recordType;
        default = {};
      };
    };
  };

  update-dns = pkgs.local.writeNushellApplication {
    name = "dns-update";
    text = builtins.readFile ./update-dns.nu;
  };

  filterMapEnabled = attrs: lib.pipe attrs [
    (lib.filterAttrs (_: v: v.enable))
    (lib.mapAttrs (_: v: lib.removeAttrs v ["enable"]))
  ];

  finalConfig = {
    domains = lib.mapAttrs (domain: v:
      v // {
        dnsRecords = lib.mapAttrs (_: v:
          # manually replace @ with apex domain
          lib.mapAttrsRecursive (p: v:
            if lib.last p == "comment" then v else
            if ! lib.isString v then v else
            lib.replaceStrings ["@"] [domain] v
          ) v
        ) (filterMapEnabled v.dnsRecords);
      }
    ) (filterMapEnabled cfg.domains);
  };
in
{
  options.services.cloudflare-dns = {
    enable = lib.mkEnableOption "cloudflare DNS record updating";
    domains = lib.mkOption {
      description = "Domains to update.";
      type = types.attrsOf (types.submodule domainSubmodule);
      default = {};
    };

    apiTokenFile = lib.mkOption {
      description = ''
        The path to a file containing the CloudFlare API token.
        The file must have the form `CLOUDFLARE_API_TOKEN=...`
        see: https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#EnvironmentFile=
      '';
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    frequency = lib.mkOption {
      description = ''
        Run cloudflare-dns with the given frequency (see
        {manpage}`systemd.time(7)` for the format).
        If null, do not run automatically.

        Really, this service should not need to be run except
        when config changes, so frequency can be kept at null
        in most situations.
      '';
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.cloudflare-dns = {
      description = "CloudFlare DNS Record Updater";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ReadOnlyPaths = [ "/" ];

        EnvironmentFile = cfg.apiTokenFile;

        ExecStart = "${lib.getExe update-dns} ${builtins.toFile "dns-config.json" (builtins.toJSON finalConfig)}";
      };
    }
    // lib.optionalAttrs (cfg.frequency != null) {
      startAt = cfg.frequency;
    };
  };
}
