{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) types;

  cfg = config.services.factorio-servers;

  serverModuleType = types.submodule [
    {
      _module.args = { inherit lib pkgs; };
    }
    (import ./server-config.nix)
  ];
in
{
  options = {
    services.factorio-servers = lib.mkOption {
      type = types.lazyAttrsOf serverModuleType;
    };
  };

  config = {
    systemd = lib.mkMerge (lib.mapAttrsToList (_: config: config.systemd) cfg);
    networking = lib.mkMerge (lib.mapAttrsToList (_: config: config.networking) cfg);
  };
}
