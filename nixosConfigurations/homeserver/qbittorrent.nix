{
  lib,
  pkgs,
  config,
  ...
}:

let
  profileDir = "/var/lib";
  qbittorrentDir = "${profileDir}/qBittorrent";

  mediaDir = "/var/lib/Media";

  torrentsDir = "/external/storage/Torrents";

  cfg = config.services.qbittorrent;

  buildLibrary = pkgs.writeShellApplication {
    name = "buildLibrary";
    text = lib.readFile ./buildLibrary.sh;
    runtimeInputs = [
      pkgs.fd
    ];
  };

  torrentFinished = pkgs.writeShellScriptBin "torrentFinished" ''
    ${lib.getExe buildLibrary} ${
      lib.escapeShellArgs [
        mediaDir
        cfg.serverConfig.BitTorrent.Session.DefaultSavePath
      ]
    }
  '';
in
{
  config = {
    persist.system = {
      directories = [
        qbittorrentDir
        {
          directory = mediaDir;
          mode = "775";
          inherit (cfg) user group;
        }
      ];
    };
    systemd.tmpfiles.settings.qbittorrent = {
      ${torrentsDir}."d" = {
        mode = "0775";
        inherit (cfg) user group;
      };
    };

    users.users.${config.setups.config.username}.extraGroups = [ cfg.group ];

    nginx.hosts.qbit = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${lib.toString cfg.webuiPort}";
      };
    };
    dnsRecords.qbit.record = {
      type = "CNAME";
      name = "qbit";
      content = "raw.@";
      proxied = true;
    };

    nginx.hosts.tracker = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${lib.toString cfg.serverConfig.Preferences.Advanced.trackerPort}";
      };
    };
    dnsRecords.tracker.record = {
      type = "CNAME";
      name = "tracker";
      content = "raw.@";
      proxied = true;
    };

    networking.firewall.allowedTCPPorts = [
      config.services.qbittorrent.torrentingPort
    ];
    networking.firewall.allowedUDPPorts = [
      config.services.qbittorrent.torrentingPort
    ];

    services.qbittorrent = {
      enable = true;

      inherit profileDir;

      webuiPort = 8080;
      torrentingPort = 49161;

      serverConfig = {
        LegalNotice.Accepted = true;
        Preferences = {
          WebUI = {
            Username = "nixos";
            Password_PBKDF2 = "@ByteArray(HOT7saYR0avFnr4IR5yMcg==:H6jLAYTsUaV4DYiqj/nNyIhZHn4+o6i2lt7cZS7paagPgeMbO6omUWsvlwEupIiL53yp8vf1prOEWL5DD4WTuw==)";
          };
          General.Locale = "en";
        };

        BitTorrent = {
          Session = {
            # auto torrent management
            DisableAutoTMMByDefault = false;
            DisableAutoTMMTriggers = {
              CategorySavePathChanged = false;
              DefaultSavePathChanged = false;
            };

            DefaultSavePath = torrentsDir;
            TorrentExportDirectory = "${torrentsDir}/prev-torrents";
            # path to store incomplete torrents
            TempPath = "${torrentsDir}/temp";
            # but don't use it by default
            TempPathEnabled = false;

            # disable queuing by default
            QueueingSystemEnabled = false;
            MaxActiveDownloads = 3;
            MaxActiveUploads = 17;
            MaxActiveTorrents = 20;

            # in KiB/s
            AlternativeGlobalDLSpeedLimit = 80 * 1024;
            AlternativeGlobalUPSpeedLimit = 40 * 1024;
            # use alt by default, to reduce network usage
            UseAlternativeGlobalSpeedLimit = true;
          };
        };

        AutoRun = {
          enabled = true;
          program = lib.getExe torrentFinished;
        };

        Network.PortForwardingEnabled = false;

        BitTorrent.TrackerEnabled = true;
        Preferences.Advanced.trackerPort = 7777;
      };
    };
  };
}
