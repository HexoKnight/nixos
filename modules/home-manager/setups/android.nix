{ lib, pkgs, config, ... }:

let
  cfg = config.setups.android;

  configDir = ".local/share/android";
in
{
  options.setups.android = {
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
