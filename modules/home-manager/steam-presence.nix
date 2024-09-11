{ lib, pkgs, config, ... }:

let
  inherit (lib) mkOption mkEnableOption types;
  cfg = config.steam-presence;

  fullConfigDir = "${config.home.homeDirectory}/${cfg.configDir}";
in
{
  options.steam-presence = {
    enable = mkEnableOption "steam-presence";

    package = mkOption {
      description = "The package to use for steam-presence.";
      type = types.package;
      default = pkgs.local.steam-presence;
    };
    finalPackage = mkOption {
      description = "Resulting configured package.";
      type = types.package;
      readOnly = true;
    };

    configDir = mkOption {
      description = "Path where config and data files will be stored (relative to $HOME).";
      type = types.str;
      # would use config.xdg.configHome but that causes infinite recursion when persisted
      # something about fileSystems cannot depend on user stuff idk
      default = ".config/steam-presence";
    };
  };

  config = lib.mkIf cfg.enable {
    steam-presence.finalPackage = cfg.package.override {
      config_path_py = /* python */ ''
        return r"""${fullConfigDir}"""
      '';
    };

    persist-home = {
      directories = [ cfg.configDir ];
    };

    # see upstream's `steam-presence.service` for explanation
    # all except those indicated are identical to upstream
    systemd.user.services.steam-presence = {
      Unit = {
        Description = "Discord rich presence from Steam on Linux";
        Documentation = "https://github.com/JustTemmie/steam-presence";
      };
      Service = {
        # changed from upstream
        ExecStart = lib.getExe cfg.finalPackage;

        Type = "simple";

        Nice = "19";

        SuccessExitStatus = "130";

        NoNewPrivileges = "true";
        ProtectSystem = "strict";
        # changed from upstream
        ReadWritePaths = "-" + fullConfigDir;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
