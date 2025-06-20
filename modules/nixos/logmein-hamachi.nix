{ lib, config, ... }:

let
  cfg = config.services.logmein-hamachi;
in
{
  options.services.logmein-hamachi = {
    # already exists in upstream nixos module
    # enable = lib.mkEnableOption "logmein hamachi";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.allowUnfreePkgs = [
      "logmein-hamachi"
    ];

    persist.system.directories = [
      "/var/lib/logmein-hamachi"
    ];
  };
}
