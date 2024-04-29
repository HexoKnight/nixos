{ username, persistence, desktop, personal-gaming, ... }:

{ config, lib, pkgs, inputs, unstable-overlay, ... }:

with lib;
let
  homeDirectory = "/home/" + username;
in {
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
    inputs.nix-index-database.hmModules.nix-index
  ] ++ lists.optionals desktop [ ./plasma.nix ./hyprland.nix ];

  options = {
  };

  config = mkMerge [{
    home = { inherit username homeDirectory; };

    nixpkgs.overlays = [ unstable-overlay ];
    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [
      "google-chrome"
      "discord"
      "code"
      "vscode"
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

    programs.nix-index-database.comma.enable = true;

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
        ".ssh"
        "dotfiles"
        ".vim"
        ".config/sops"
        ".config/syncthing"
      ] ++ lists.optionals desktop [
        ".config/GitHub Desktop"
        ".config/Code"
        ".vscode"
      ] ++ lists.optionals personal-gaming [
        ".config/discord"
        ".config/Vencord"
        ".config/google-chrome"
        # cache for logged in accounts and stuff
        ".cache/google-chrome"
        {
          directory = ".local/share/Steam";
          method = "symlink";
        }
        ".config/unity3d"
      ];
    };
  })
  (attrsets.optionalAttrs (desktop) {
    home.packages = with pkgs; [
      (google-chrome.override {
        commandLineArgs = "--incognito";
      })
      github-desktop
    ];

    services.wlsunset = {
      enable = true;
      # they are in fact not allowed to be identical :/
      temperature.day = 5001;
      temperature.night = 5000;
      # i do not care but they have to be set
      latitude = "";
      longitude = "";
    };

    programs.alacritty = {
      enable = true;
    };

    programs.vscode = {
      enable = true;
      package = pkgs.vscode.fhs;
    };

    home.pointerCursor = {
      name = "Win10OS-cursors";
      size = 24;
      package = pkgs.callPackage "${inputs.self}/packages/Win10OS-cursors.nix" {};
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
