{ config, ... }:

let
  profileDir = "/var/lib";
  qbittorrentDir = "${profileDir}/qBittorrent";

  torrentsDir = "/var/lib/Torrents";

  inherit (config.services.qbittorrent) user group;
in
{
  config = {
    persist.system = {
      directories = [
        qbittorrentDir
        {
          directory = torrentsDir;
          mode = "0755";
          inherit user group;
        }
      ];
    };

    nginx.hosts.qbit = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
      };
    };
    dnsRecords.qbittorrent.record = {
      type = "CNAME";
      name = "qbit";
      content = "raw.@";
      proxied = true;
    };

    services.qbittorrent = {
      enable = true;

      inherit profileDir;

      webuiPort = 8080;
      openFirewall = true;

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
      };
    };
  };
}
