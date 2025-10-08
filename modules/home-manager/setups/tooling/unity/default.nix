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
      "unityhub"
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
          # TODO(25.11): until recent changes (specifically `cmd` setting ones) make it to stable
          plugin = pkgs.vimPlugins.roslyn-nvim.overrideAttrs {
            version = "2025-09-10";
            src = pkgs.fetchFromGitHub {
              owner = "seblyng";
              repo = "roslyn.nvim";
              rev = "14ff65704f2a1658f55646618d6520cf00b3f576";
              sha256 = "1yrvipfdb2kxn5lg9712zxgwjydv2njbjr1cd6gljh2ynxy9zg3v";
            };
          };
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
