{ lib, pkgs, config, ... }:

let
  # https://github.com/nix-community/steam-fetcher
  steam-fetcher-flake = builtins.getFlake "github:nix-community/steam-fetcher/12f66eafb7862d91b3e30c14035f96a21941bd9c";

  zomboid-server = pkgs.callPackage ./dedicated-server.nix {};

  zomboid-client = pkgs.writeShellApplication {
    name = "zomboid-client";

    runtimeEnv = {
      ZOMBOID_UNIT = "zomboid.service";
      ZOMBOID_SOCKET = socketPath;
    };
    runtimeInputs = [
      pkgs.socat
    ];

    text = builtins.readFile ./zomboid-client.sh;
  };

  dataDir = "/var/lib/Zomboid";
  socketPath = "/run/zomboid/control";

  user = "pzuser";
  group = "pzuser";
in
{
  config = {
    nixpkgs-overlays = [ steam-fetcher-flake.outputs.overlays.default ];

    nixpkgs.allowUnfreePkgs = [ "project-zomboid-server" "steamworks-sdk-redist" ];

    environment.systemPackages = [
      zomboid-server
      zomboid-client
    ];

    users.users.${config.setups.config.username}.extraGroups = [ group ];

    users.users.${user} = {
      isSystemUser = true;
      group = group;
    };
    users.groups.${group} = {};

    # based on: https://pzwiki.net/wiki/Dedicated_server#Systemd
    systemd = {
      tmpfiles.settings.zomboid = {
        "${dataDir}".d = {
          mode = "770";
          inherit user group;
        };
      };
      services.zomboid = {
        description = "Project Zomboid Server";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];

        serviceConfig = {
          PrivateTmp = true;
          Type = "exec";
          User = user;
          Group = group;
          KillSignal = "SIGCONT";

          WorkingDirectory = dataDir;
          ReadOnlyPaths = [ "/" ];
          ReadWritePaths = [
            dataDir
            "/tmp"
          ];

          ExecStart = "${lib.getExe zomboid-server} -cachedir=${dataDir}";
          StandardInput = "file:" + socketPath;
          # shouldn't be necessary but just in case
          Sockets = [ "zomboid.socket" ];
        };

        preStop = ''
          echo quit >${socketPath}
        '';
      };
      sockets.zomboid = {
        bindsTo    = [ "zomboid.service" ];
        before     = [ "zomboid.service" ];
        requiredBy = [ "zomboid.service" ];

        socketConfig = {
          ListenFIFO = socketPath;
          RemoveOnStop = true;
          FileDescriptorName = "control";
          SocketMode = 0660;
          SocketUser = user;
          SocketGroup = group;
        };
      };
    };
  };
}
