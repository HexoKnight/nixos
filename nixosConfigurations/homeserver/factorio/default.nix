{
  lib,
  config,
  ...
}:

{
  imports = [
    ./servers.nix
  ];

  config = {
    nixpkgs.allowUnfreePkgs = [ "factorio-headless" ];

    persist.system = {
      directories = lib.mapAttrsToList (_: config: {
        # due to DynamicUser=true
        # this is where the actual directory is stored
        directory = "/var/lib/private/${config.stateDirName}";
        user = "nobody";
        group = "nogroup";
      }) config.services.factorio-servers;

    };

    services.factorio-servers =
      let
        commonOpts = {
          enable = true;

          openFirewall = true;
          requireUserVerification = false;

          admins = [ "HexoKnight" ];

          saveName = "server";
          loadLatestSave = true;
          autosave-interval = 60;
        };
      in
      {
        main = commonOpts // {
          game-name = "HexoKnight's Server";
          # default for reference
          port = 34197;
        };
        other = commonOpts // {
          game-name = "HexoKnight's Other Server";
          port = 34198;
        };
      };

    dnsRecords = {
      factorio.record = {
        type = "CNAME";
        name = "factorio";
        content = "raw.@";
        proxied = false;
      };
    }
    // lib.mapAttrs' (
      name: config:
      lib.nameValuePair "factorio-server-${name}" {
        enable = config.enable;
        record = {
          type = "SRV";
          name = "_factorio._udp.${name}.factorio";
          data = {
            target = "factorio.@";
            port = config.port;
            priority = 0;
            weight = 0;
          };
        };
      }
    ) config.services.factorio-servers;
  };
}
