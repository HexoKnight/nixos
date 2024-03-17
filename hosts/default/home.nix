{ config, pkgs, inputs, unstable-overlay, ... }:

let
  username = "harvey";
  homeDirectory = "/home/" + username;
in {
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
    lshw
    usbutils
    pciutils
    psmisc
    ethtool
    google-chrome
    github-desktop

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

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  #programs.vim = {
  #  enable = true;
  #  defaultEditor = true;
  #  extraConfig = (builtins.readFile (inputs.dotfiles + "/vimrc"));
  #};
  #home.file.".vimrc".source = inputs.dotfiles + "/vimrc";

  programs.git = {
    enable = true;
    userName = "HexoKnight";
    userEmail = "harvey.gream@gmail.com";
    includes = pkgs.lib.lists.singleton {
      contents = {
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

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. If you don't want to manage your shell through Home
  # Manager then you have to manually source 'hm-session-vars.sh' located at
  # either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/harvey/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
