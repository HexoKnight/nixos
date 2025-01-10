{ pkgs, inputs, config, ... }:

let
  dataDir = "/var/lib/minecraft";

  inherit (config.services.minecraft-servers) user group;
in
{
  config = {
    nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

    nixpkgs.allowUnfreePkgs = [ "minecraft-server" ];

    persist.system = {
      directories = [
        {
          directory = dataDir;
          inherit user group;
        }
      ];
    };

    users.users.${config.setups.config.username}.extraGroups = [ group ];
    
    services.minecraft-servers = {
      enable = true;
      eula = true;
      openFirewall = true;
      inherit dataDir;

      managementSystem = {
        systemd-socket = {
          enable = true;
          stdinSocket.path = name: "/run/minecraft/${name}.control";
        };
      };

      servers = {
        main = {
          enable = true;
          autoStart = true;
          restart = "always";

          package = pkgs.minecraftServers.vanilla-1_21_4;

          serverProperties = {
            server-port = 25565;
            motd = ''this is \u00A7n\u00A7o\u00A7nthe\u00A7r server of \u00A7kthere is nothing\u00A7r'';
          };
          jvmOpts = "-Xmx4G -Xms500M";

          symlinks = {
            "mods" = "${pkgs.fetchPackwizModpack {
              url = "file://${./modpack}/pack.toml";
              packHash = "sha256-VF6WhWcsI42njRCUtKKXE3dZF4yBwj6vcv2usTFflW8=";
            }}/mods";
          };
        };
      };
    };
  };
}
