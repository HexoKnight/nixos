{ lib, pkgs, config, nixosConfig, ... }:

let
  cfg = config.btop;
in
{
  options.btop = {
    enable = lib.mkEnableOption "btop";
  };
  config = lib.mkIf cfg.enable {
    programs.btop = {
      enable = true;
      package = pkgs.btop.override {
        cudaSupport = true;
        rocmSupport = true;
      };
      settings = {
        color_theme = "ayu";
        theme_background = false;
        vim_keys = true;
        update_ms = 2000;
        clock_format = "/user@/host - %X %d-%M-%Y - up: /uptime";

        show_uptime = false;

        swap_disk = false;
        disks_filter = "exclude=" + lib.concatStringsSep " " (
          lib.mapAttrsToList
            (mount: config: if lib.elem "bind" config.options then mount else "")
            nixosConfig.fileSystems or {}
        );
      };
    };
  };
}
