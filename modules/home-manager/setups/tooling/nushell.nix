{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.setups.tooling.nushell;
in
{
  options.setups.tooling.nushell = {
    enable = lib.mkEnableOption "nushell stuff";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.nushell
    ];

    neovim.main.lspServers = {
      nushell = { };
    };
  };
}
