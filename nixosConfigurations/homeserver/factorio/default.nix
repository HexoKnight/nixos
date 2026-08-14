{
  lib,
  pkgs,
  config,
  ...
}:

let
  factorio-headless-2-1-14 = pkgs.factorio-headless-experimental.override {
    # https://github.com/NixOS/nixpkgs/blob/a08dea4d45b3fff23d98c49f4ecab97f6ea2b23b/pkgs/by-name/fa/factorio/versions.json
    versionsJson = lib.toFile "versions.json" (
      lib.toJSON {
        x86_64-linux.headless.experimental = {
          candidateHashFilenames = [
            "factorio-headless_linux_2.1.14.tar.xz"
            "factorio_headless_x64_2.1.14.tar.xz"
          ];
          name = "factorio_headless_x64-2.1.14.tar.xz";
          needsAuth = false;
          sha256 = "cc97aa4bac26de625260af32515c839021c0c9f0c076a518329d7a105e213d7d";
          tarDirectory = "x64";
          url = "https://factorio.com/get-download/2.1.14/headless/linux64";
          version = "2.1.14";
        };
      }
    );
  };
in
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

          package = factorio-headless-2-1-14;
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
