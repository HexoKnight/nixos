{ username, desktop, ... }:

{ config, lib, pkgs, inputs, unstable-overlay, ... }:

with lib;
let
  homeDirectory = "/home/" + username;
in {
  options = {
  };

  config = mkMerge [{
      # Home Manager needs a bit of information about you and the paths it should
      # manage.
      home = { inherit username homeDirectory; };

      nixpkgs.overlays = [ unstable-overlay ];

      # This value determines the Home Manager release that your configuration is
      # compatible with. This helps avoid breakage when a new Home Manager release
      # introduces backwards incompatible changes.
      #
      # You should not change this value, even if you update Home Manager. If you do
      # want to update the value, then make sure to first check the Home Manager
      # release notes.
      home.stateVersion = "23.11"; # Please read the comment before changing.

      nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [
        "google-chrome"
      ];
      home.packages = with pkgs; [
        # tools
        lshw
        usbutils
        pciutils
        psmisc
        ethtool

        (vim-full.customize {
          name = "vim";
          # vimrcFile = inputs.dotfiles + "/vimrc";
          gvimrcFile = inputs.dotfiles + "/gvimrc";
          vimrcConfig = {
            customRC = (builtins.readFile (inputs.dotfiles + "/vimrc"));
            plug.plugins = [];
          };
        })
        (vim-full.customize {
          name = "vim-local";
          executableName = "$exe-local";
          gvimrcFile = (config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/dotfiles/gvimrc");
          vimrcConfig = {
            customRC = ''
              source ${vimPlugins.vim-plug}/plug.vim
              source ${homeDirectory}/dotfiles/vimrc
            '';
            plug.plugins = [];
          };
        })
      ];

      programs.git = {
        enable = true;
        userName = "HexoKnight";
        userEmail = "harvey.gream@gmail.com";
        includes = pkgs.lib.lists.singleton {
          contents = {
            core.autocrlf = false;
            init.defaultbranch = "main";
            # for github desktop
            filter.lfs.required = "true";
            filter.lfs.clean = "git-lfs clean -- %f";
            filter.lfs.smudge = "git-lfs smudge -- %f";
            filter.lfs.process = "git-lfs filter-process";
          };
        };
      };

      programs.ssh = {
        enable = true;
        matchBlocks = {
          "github.com" = {
            forwardAgent = true;
          };
        };
      };
      services.ssh-agent.enable = true;

      home.file = {
      };

      home.sessionVariables = {
        EDITOR = "vim";
      };

      # Let Home Manager install and manage itself.
      programs.home-manager.enable = true;
    }
    (attrsets.optionalAttrs (desktop) {
      home.packages = with pkgs; [
        google-chrome
        github-desktop
      ];
    })];
}
