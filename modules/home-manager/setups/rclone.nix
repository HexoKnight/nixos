{ lib, pkgs, config, ... }:

let
  inherit (lib) mkEnableOption;

  cfg = config.setups.rclone;
in
{
  options.setups.rclone = {
    enable = mkEnableOption "rclone";
    bruhpi.enable = mkEnableOption "bruhpi sftp" // { default = true; };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.rclone
    ];

    persist-home = {
      directories = [ ".cache/rclone" ];
    };

    xdg.configFile."rclone/rclone.conf".text =
      lib.optionalString cfg.bruhpi.enable (lib.generators.toINI {} {
        homeserver = {
          type = "sftp";
          user = "nixos";
          host = "ssh.bruhpi.uk";
          port = 22;
          key_use_agent = true;
          shell_type = "unix";
          md5sum_command = "md5sum";
          sha1sum_command = "sha1sum";
        };
        bruhpi = {
          type = "sftp";
          user = "bruh";
          host = "ssh.bruhpi.uk";
          port = 2222;
          key_use_agent = true;
          shell_type = "unix";
          md5sum_command = "md5sum";
          sha1sum_command = "sha1sum";
        };
      });
  };
}
