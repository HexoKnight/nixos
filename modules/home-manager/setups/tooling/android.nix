{ lib, pkgs, config, ... }:

let
  cfg = config.setups.tooling.android;

  configDir = ".local/share/android";
in
{
  options.setups.tooling.android = {
    enable = lib.mkEnableOption "android tools";
  };

  config = lib.mkIf cfg.enable {
    persist-home = {
      directories = [
        configDir
      ];
    };

    home.sessionVariables = {
      ANDROID_USER_HOME = "$HOME/${configDir}";
    };

    home.packages = [ pkgs.android-tools ];
  };
}
