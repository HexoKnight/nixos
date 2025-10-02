{ lib, pkgs, config, ... }:

let
  cfg = config.setups.tooling.typescript;
in
{
  options.setups.tooling.typescript = {
    enable = lib.mkEnableOption "typescript dev stuff";
  };

  config = lib.mkIf cfg.enable {
    # very minimal right now

    neovim.main.lspServers = {
      vtsls = {
        extraPackages = [ pkgs.vtsls ];
      };
    };
  };
}
