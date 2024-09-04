{ lib, config, nixosConfig, ... }:

let
  cfg = config.flatpak;
in
{
  options.flatpak = {
    enable = lib.mkEnableOption "flatpak support (this does not install it)" // {
      default = nixosConfig.services.flatpak.enable or false;
    };
  };

  config = lib.mkIf cfg.enable {
    persist-home = {
      directories = [
        ".local/share/flatpak"
        # flatpak user data
        ".var/app"
      ];
    };
  };
}
