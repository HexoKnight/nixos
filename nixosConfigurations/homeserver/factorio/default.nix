{
  config,
  ...
}:

{
  config = {
    nixpkgs.allowUnfreePkgs = [ "factorio-headless" ];

    persist.system = {
      directories = [
        {
          # due to DynamicUser=true
          # this is where the actual directory is stored
          directory = "/var/lib/private/${config.services.factorio.stateDirName}";
          user = "nobody";
          group = "nogroup";
        }
      ];
    };

    services.factorio = {
      enable = true;

      # default for reference
      port = 34197;
      openFirewall = true;
      requireUserVerification = false;

      game-name = "HexoKnight's Server";
      admins = [ "HexoKnight" ];

      saveName = "server";
      loadLatestSave = true;
      autosave-interval = 60;
    };

    dnsRecords = {
      factorio.record = {
        type = "SRV";
        name = "_factorio._udp.factorio";
        data = {
          target = "raw.@";
          port = config.services.factorio.port;
          priority = 0;
          weight = 0;
        };
      };
    };
  };
}
