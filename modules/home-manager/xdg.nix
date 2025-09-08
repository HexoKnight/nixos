{ lib, pkgs, config, ... }:

let
  cfg = config.xdg;

  mkListIf = condition: value: [ (lib.mkIf condition value) ];

  packageType = lib.types.submodule ({ config, ... }: {
    options = {
      command = lib.mkOption {
        description = "";
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      desktopFile = lib.mkOption {
        description = "";
        type = lib.types.nullOr lib.types.str;
        default = if config.command == null then null else "${config.command}.desktop";
      };
    };
  });
in
{
  options.xdg = {
    defaults = {
      terminal = lib.mkOption {
        description = "";
        type = packageType;
        default = {};
      };
      browser = lib.mkOption {
        description = "";
        type = packageType;
        default = {};
      };
    };
  };

  config = lib.mkMerge (
    mkListIf (cfg.defaults.terminal.command != null) {
      home.sessionVariables = {
        TERMINAL = cfg.defaults.terminal.command;
      };
    } ++
    mkListIf (cfg.defaults.terminal.desktopFile != null) {
      # TODO(25.11):
      # xdg.terminal-exec = {
      #   enable = true;
      #   settings = {
      #     default = [ cfg.defaults.terminal.desktopFile ];
      #   };
      # };
    } ++
    mkListIf (cfg.defaults.browser.command != null) {
      home.packages = [
        (pkgs.writeShellScriptBin "x-www-browser" ''
          exec ${cfg.defaults.browser.command} "$@"
        '')
      ];
    } ++
    mkListIf (cfg.defaults.browser.desktopFile != null) {
      xdg.mimeApps = {
        enable = true;

        defaultApplications = {
          "text/html"              = cfg.defaults.browser.desktopFile;
          "x-scheme-handler/http"  = cfg.defaults.browser.desktopFile;
          "x-scheme-handler/https" = cfg.defaults.browser.desktopFile;
        };
      };
    }
  );
}
