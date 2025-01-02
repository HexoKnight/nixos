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
  runDir = "/run/zomboid";

  overlay = {
    dir = runDir + "/server";
    workdir = dataDir + "/empty";
    upperdir = dataDir + "/runtime";
  };
  socketPath = runDir + "/control";

  user = "pzuser";
  group = "pzuser";
in
{
  config = {
    nixpkgs-overlays = [ steam-fetcher-flake.outputs.overlays.default ];

    nixpkgs.allowUnfreePkgs = [ "project-zomboid-server" "steamworks-sdk-redist" ];

    persist.system = {
      directories = [
        dataDir
      ];
    };
    networking.firewall.allowedUDPPorts = [ 16261 16262 ];

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
        "${overlay.dir}".d = {
          mode = "770";
          inherit user group;
        };
        "${overlay.upperdir}".d = {
          mode = "770";
          inherit user group;
        };
      };
      services.zomboid = {
        description = "Project Zomboid Server";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];

        # restart automatically but stop after 3 restarts in 6 minutes
        unitConfig = {
          StartLimitIntervalSec = 360;
          StartLimitBurst = 3;
        };
        serviceConfig = {
          Restart = "always";
          RestartMode = "direct";
        };

        # despite having Restart=always, the service does not restart on success
        # so manually convert success into failure
        script = ''
          ${lib.getExe zomboid-server} -cachedir=${dataDir} && exit 1
        '';

        serviceConfig = {
          PrivateTmp = true;
          Type = "exec";
          User = user;
          Group = group;
          KillSignal = "SIGCONT";

          WorkingDirectory = overlay.dir;
          ReadOnlyPaths = [ "/" ];
          ReadWritePaths = [
            dataDir
            runDir
            "/tmp"
          ];

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
      mounts = lib.singleton {
        bindsTo    = [ "zomboid.service" ];
        before     = [ "zomboid.service" ];
        requiredBy = [ "zomboid.service" ];

        type = "overlay";
        what = "overlay";
        where = overlay.dir;
        options = "lowerdir=${zomboid-server},upperdir=${overlay.upperdir},workdir=${overlay.workdir}";
      };
    };
  };
}
