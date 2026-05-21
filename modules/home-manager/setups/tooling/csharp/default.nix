{ lib, pkgs, config, ... }:

let
  cfg = config.setups.tooling.csharp;
in
{
  options.setups.tooling.csharp = {
    enable = lib.mkEnableOption "csharp stuff";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (with pkgs.dotnetCorePackages;
        combinePackages [sdk_8_0 sdk_9_0]
      )
    ];

    neovim.main = {
      pluginsWithConfig = [
        {
          plugin = pkgs.vimPlugins.roslyn-nvim;
          type = "lua";
          config = builtins.readFile ./roslyn-nvim.lua;
        }
      ];

      extraPackages = [
        pkgs.roslyn-ls
      ];
    };
  };
}
