{ pkgs, ... }:

let
  profileDir = "/var/lib";
in
{
  imports = [
    # https://github.com/NixOS/nixpkgs/pull/287923
    (builtins.fetchTree {
      type = "file";
      url = "https://raw.githubusercontent.com/NixOS/nixpkgs/ed446194bbf78795e4ec2d004da093116c93653f/nixos/modules/services/torrent/qbittorrent.nix";
      narHash = "sha256-StMwVMrGi5kbk96rNFBfLiVuYKFTE/xkkeDC3wO70lQ=";
    }).outPath
  ];

  config = {
    persist.system = {
      directories = [
        "${profileDir}/qBittorrent"
      ];
    };

    services.qbittorrent = {
      enable = true;
      package = pkgs.qbittorrent-nox.overrideAttrs (oldAttrs: {
        meta = oldAttrs.meta // {
          mainProgram = "qbittorrent-nox";
        };
      });

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
      };
    };
  };
}
