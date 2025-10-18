{ lib, pkgs, config, ... }:

let
  cfg = config.setups.direnv;
in
{
  options.setups.direnv = {
    enable = lib.mkEnableOption "direnv";
  };

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    neovim.main.pluginsWithConfig = [
      {
        plugin = pkgs.vimUtils.buildVimPlugin {
          pname = "direnv.nvim";
          version = "2025-06-09";
          src = pkgs.fetchFromGitHub {
            owner = "NotAShelf";
            repo = "direnv.nvim";
            rev = "4dfc8758a1deab45e37b7f3661e0fd3759d85788";
            sha256 = "sha256-KqO8uDbVy4sVVZ6mHikuO+SWCzWr97ZuFRC8npOPJIE=";
          };
        };
        type = "lua";
        config = /* lua */ ''
          require('direnv').setup({
            autoload_direnv = true,
            statusline = {
              enabled = true,
            },
            notifications = {
             silent_autoload = false,
            },
          })
        '';
      }
    ];
  };
}
