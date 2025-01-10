{ lib, pkgs, config, ... }:

let
  bruh-bot = pkgs.callPackage ./bruh-bot.nix {};

  dataDir = "/var/lib/Bruh-Bot";
  runDir = "/run/bruh-bot";

  overlay = {
    dir = runDir;
    workdir = dataDir + "/empty";
    upperdir = dataDir + "/runtime";
  };

  user = "bruhbot";
  group = "bruhbot";
in
{
  config = {
    persist.system = {
      directories = [
        dataDir
      ];
    };

    environment.systemPackages = [ bruh-bot ];

    users.users.${config.setups.config.username}.extraGroups = [ group ];

    users.users.${user} = {
      isSystemUser = true;
      group = group;
    };
    users.groups.${group} = {};

    systemd = {
      tmpfiles.settings.bruhbot = {
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
      services.bruhbot = {
        description = "Bruh Bot";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];

        serviceConfig = {
          PrivateTmp = true;
          Type = "exec";
          User = user;
          Group = group;

          WorkingDirectory = overlay.dir;
          ReadOnlyPaths = [ "/" ];
          ReadWritePaths = [
            runDir
            "/tmp"
          ];

          ExecStart = lib.getExe bruh-bot;
        };
      };
      mounts = lib.singleton {
        bindsTo    = [ "bruhbot.service" ];
        before     = [ "bruhbot.service" ];
        requiredBy = [ "bruhbot.service" ];

        type = "overlay";
        what = "overlay";
        where = overlay.dir;
        options = "lowerdir=${bruh-bot.src},upperdir=${overlay.upperdir},workdir=${overlay.workdir}";
      };
    };
  };
}
