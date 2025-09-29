{ lib, pkgs, config, ... }:

let
  cfg = config.setups.podman;
in
{
  options.setups.podman = {
    enable = lib.mkEnableOption "podman";
  };

  config = lib.mkIf cfg.enable {
    virtualisation = {
      containers = {
        enable = true;
        containersConf.settings = {
          engine = {
            compose_providers = [ (lib.getExe pkgs.podman-compose) ];
            # disables log line indicating that podman is running an external compose provider
            compose_warning_logs = false;
          };
        };
        registries.search = lib.mkForce [ "docker.io" ];
      };
      podman = {
        enable = true;
        # Required for containers under podman-compose to be able to talk to each other.
        defaultNetwork.settings.dns_enabled = true;
      };
    };

    users.groups.podman.members = [
      config.setups.config.username
    ];
  };
}
