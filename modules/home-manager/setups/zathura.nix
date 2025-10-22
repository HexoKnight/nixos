{ lib, config, ... }:

let
  cfg = config.setups.zathura;
in
{
  options.setups.zathura = {
    enable = lib.mkEnableOption "zathura";
  };

  config = lib.mkIf cfg.enable {
    persist-home = {
      directories = [
        ".local/share/zathura"
      ];
    };

    programs.zathura = {
      enable = true;
    };
  };
}
