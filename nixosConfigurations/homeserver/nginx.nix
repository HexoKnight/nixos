{ lib, config, modulesPath, ... }:

let
  inherit (lib) types;

  cfg = config.nginx;

  rootDomain = "bruhpi.uk";

  hostsSubmodule = types.submoduleWith {
    modules = [
      (import "${modulesPath}/services/web-servers/nginx/vhost-options.nix" { inherit config lib; })
      ({ name, config, ... }: {
        config = {
          serverName = lib.mkDefault "${name}.${rootDomain}";
          addSSL = lib.mkDefault (!config.onlySSL && !config.forceSSL && !config.rejectSSL);
          useACMEHost = lib.mkDefault rootDomain;
        };
      })
    ];
  };
in
{
  options.nginx = {
    hosts = lib.mkOption {
      description = "Declarative vhost config";
      type = types.attrsOf hostsSubmodule;
      default = {};
    };
  };

  config = {
    acme.users.${rootDomain} = [ config.services.nginx.user ];

    networking.firewall.allowedTCPPorts = [ 80 443 ];

    nginx.hosts.${rootDomain} = {
      serverName = rootDomain;
      default = true;
      locations."/" = {
        return = "404";
      };
    };

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      virtualHosts = cfg.hosts;
    };
  };
}
