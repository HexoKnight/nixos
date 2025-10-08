{ lib, pkgs, config, ... }:

let
  cfg = config.setups.tooling.c;
in
{
  options.setups.tooling.c = {
    enable = lib.mkEnableOption "c dev stuff";
  };

  config = lib.mkIf cfg.enable {
    # very minimal right now

    neovim.main.lspServers = {
      clangd = {
        extraPackages = [ pkgs.clang-tools ];
      };
    };
  };
}
