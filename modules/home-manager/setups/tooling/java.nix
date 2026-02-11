{ lib, pkgs, config, ... }:

let
  cfg = config.setups.tooling.java;
in
{
  options.setups.tooling.java = {
    enable = lib.mkEnableOption "java stuff";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.jdk
    ];

    neovim.main = {
      pluginsWithConfig = [
        {
          plugin = pkgs.vimPlugins.nvim-jdtls;
          type = "lua";
          config = "vim.lsp.enable('jdtls')";
        }
      ];

      extraPackages = [
        pkgs.jdt-language-server
      ];
    };
  };
}
