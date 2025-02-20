{ lib, inputs, config, ... }:

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
          autoStart = false;
          restart = "always";
          serverProperties = {
            server-port = 25565;
          };
        };
        deceased = {
          enable = true;
          autoStart = false;
          restart = "always";
          serverProperties = {
            server-port = 25566;
          };
        };
        skyfactory4 = {
          enable = true;
          autoStart = false;
          restart = "always";
          serverProperties = {
            server-port = 25567;
          };
        };
        atm9sky = {
          enable = true;
          autoStart = true;
          restart = "always";
          serverProperties = {
            server-port = 25568;
          };
        };
      };
    };

    dnsRecords = {
      minecraft.record = {
        type = "CNAME";
        name = "mc";
        content = "raw.@";
        proxied = false;
      };
    } // lib.mapAttrs' (name: config:
      lib.nameValuePair "minecraft-server-${name}" {
        enable = config.enable;
        record = {
          type = "SRV";
          name = "_minecraft._tcp.${name}.mc";
          data = {
            target = "mc.@";
            port = config.serverProperties.server-port or 25565;
            priority = 0;
            weight = 0;
          };
        };
      }
    ) config.services.minecraft-servers.servers;
  };
}
