{ username, persistence, desktop, personal-gaming, ... }:

{ config, lib, pkgs, inputs, unstable-overlay, ... }:

with lib;
let
  homeDirectory = "/home/" + username;
in {
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
  ];

  options = {
  };

  config = mkMerge [{
    home = { inherit username homeDirectory; };

    nixpkgs.overlays = [ unstable-overlay ];
    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [
      "google-chrome"
      "discord"
    ];

    # This value determines the Home Manager release that your configuration is
    # compatible with. This helps avoid breakage when a new Home Manager release
    # introduces backwards incompatible changes.
    #
    # You should not change this value, even if you update Home Manager. If you do
    # want to update the value, then make sure to first check the Home Manager
    # release notes.
    home.stateVersion = "23.11"; # Please read the comment before changing.

    home.packages = with pkgs; [
      # tools
      lshw
      usbutils
      pciutils
      psmisc
      ethtool
      ssh-to-age


      # programs
      lf
      fd

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
  (attrsets.optionalAttrs (persistence) {
    home.persistence."/persist/home/${username}" = {
      allowOther = true;
      directories = [
        "Documents"
        ".nixos"
        "dotfiles"
        ".vim"
        ".config/GitHub Desktop"
        ".config/sops"
        ".config/syncthing"
        ".config/Vencord"
        ".ssh"
      ];
    };
  })
  (attrsets.optionalAttrs (desktop) {
    home.packages = with pkgs; [
      google-chrome
      github-desktop
    ];

    programs.alacritty = {
      enable = true;
    };
  })
  (attrsets.optionalAttrs (personal-gaming) {
    home.packages = with pkgs; [
      (discord.override {
        withOpenASAR = true;
        withVencord = true;
      })
    ];
  })];
}
