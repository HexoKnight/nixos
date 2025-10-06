{ lib, config, ... }:

let
  cfg = config.setups.printing;
in
{
  options.setups.printing = {
    enable = lib.mkEnableOption "printing";
  };

  config = lib.mkIf cfg.enable {
    persist.system = {
      directories = [
        "/var/lib/cups"
      ];
    };

    services.printing.enable = true;
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };
}
