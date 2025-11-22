{ lib, config, ... }:

let
  cfg = config.shikane;

  config-dir = ".config/shikane";
  config-file = "${config-dir}/config.toml";
in
{
  options.shikane = {
    enable = lib.mkEnableOption "shikane";
  };

  config = lib.mkIf cfg.enable {
    persist-home.directories = [
      config-dir
    ];

    home.packages = [
      config.services.shikane.package
    ];

    services.shikane = {
      enable = true;
    };

    home.activation.shikane-create-config = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ ! -f ~/${config-file} ]; then
          run touch ~/${config-file}
      fi
    '';
  };
}
