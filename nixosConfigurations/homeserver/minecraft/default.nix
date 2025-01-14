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
        };
      };
    };
  };
}
