{
  lib,
  config,
  ...
}:

let
  profileDir = "/var/lib";
  qbittorrentDir = "${profileDir}/qBittorrent";

  torrentsDir = "/external/storage/Torrents";

  cfg = config.services.qbittorrent;
in
{
  config = {
    persist.system = {
      directories = [
        qbittorrentDir
      ];
    };
    systemd.tmpfiles.settings.qbittorrent = {
      ${torrentsDir}."d" = {
        mode = "0755";
        inherit (cfg) user group;
      };
    };

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

            DefaultSavePath = torrentsDir;
            TorrentExportDirectory = "${torrentsDir}/prev-torrents";

            MaxActiveDownloads = 3;
            MaxActiveUploads = 17;
            MaxActiveTorrents = 20;

            # in KiB/s
            AlternativeGlobalDLSpeedLimit = 1000;
            AlternativeGlobalUPSpeedLimit = 1000;
            # use alt by default, to reduce network usage
            UseAlternativeGlobalSpeedLimit = true;
          };
        };

        Network.PortForwardingEnabled = false;

        BitTorrent.TrackerEnabled = true;
        Preferences.Advanced.trackerPort = 7777;
      };
    };
  };
}
