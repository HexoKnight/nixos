{ lib, pkgs, config, ... }:

let
  cfg = config.setups.tooling.unity;
in
{
  options.setups.tooling.unity = {
    enable = lib.mkEnableOption "unity stuff";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.unityhub
      # TODO: script to run a unity editor directly
    ];
    nixpkgs.allowUnfreePkgs = [
      "unityhub" "corefonts"
    ];

    persist-home = {
      directories = [
        ".config/unityhub"
        ".config/unity3d/Unity"
        ".config/unity3d/Preferences"
        ".config/unity3d/cache"
        ".local/share/unity3d"
      ];
    };

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

      # lspServers.roslyn_ls = {
      #   extraPackages = [ pkgs.roslyn-ls ];
      #   config = ''{}'';
      # };
    };
  };
}
