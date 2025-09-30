{ lib, config, ... }:

let
  cfg = config.setups.mangohud;
in
{
  options.setups.mangohud = {
    enable = lib.mkEnableOption "mangohud";
  };

  config = lib.mkIf cfg.enable {
    persist-home = {
      directories = [
        ".config/MangoHud"
      ];
    };

    programs.mangohud = {
      enable = true;
      enableSessionWide = true;
    };
  };
}
