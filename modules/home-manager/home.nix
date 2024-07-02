{ username, persistence, desktop, personal-gaming, disable-touchpad, hasRebuildCommand, ... }@home-inputs:

{ config, lib, pkgs, inputs, system-config, ... }:

with lib;
let
  homeDirectory = "/home/" + username;
in {
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
    inputs.nix-index-database.hmModules.nix-index
    ./neovim
  ] ++ lists.optionals desktop [
    # ./plasma.nix
    (import ./hyprland home-inputs)
  ];

  options = {
  };

  config = mkMerge [{
    home = { inherit username homeDirectory; };

    nixpkgs.overlays = system-config.nixpkgs-overlays;
    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (getName pkg) [
      "google-chrome"
    ] || builtins.elem pkg.meta.license.shortName [
      "CUDA EULA"
    ];

    # This value determines the Home Manager release that your configuration is
    # compatible with. This helps avoid breakage when a new Home Manager release
    # introduces backwards incompatible changes.
    #
    # You should not change this value, even if you update Home Manager. If you do
    # want to update the value, then make sure to first check the Home Manager
    # release notes.
    home.stateVersion = "24.05"; # Please read the comment before changing.

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
      ripgrep
      jq
      neovim-remote

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
        # executableName = "$exe-local";
        gvimrcFile = (config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/dotfiles/gvimrc");
        vimrcConfig = {
          customRC = "source ${homeDirectory}/dotfiles/vimrc";
          plug.plugins = [];
        };
      })
    ];

    programs.nix-index-database.comma.enable = true;

    programs.bat = {
      enable = true;
      extraPackages = with pkgs.bat-extras; [
        batman
      ];
    };

    programs.eza = {
      enable = true;
      icons = true;
    };

    programs.lazygit = {
      enable = true;
      settings = {
        keybinding = {
          universal = {
            rangeSelectUp = "K";
            rangeSelectDown = "J";
            scrollUpMain-alt1 = "<disabled>";
            scrollDownMain-alt1 = "<disabled>";
          };
        };
        os = {
          edit = "nvr -s --remote {{filename}}";
          editAtLine = "nvr -s --remote +{{line}} {{filename}}";
          editAtLineAndWait = "nvr -s --remote-wait +{{line}} {{filename}}";
          openDirInEditor = "nvr -s --remote {{dir}}";
        };
        promptToReturnFromSubprocess = false;
        disableStartupPopups = true;
        gui = {
          nerdFontsVersion = "3";
        };
        git.paging = {
          pager = "delta --paging=never";
        };
      };
    };

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

      delta = {
        enable = true;
        options = rec {
          features = "default";
          default = {
            file-decoration-style = "";
            file-style = "purple";
            hunk-header-decoration-style = "";
          };
          line-numbers = {
            hunk-header-style = "omit";
            line-numbers-left-format = "{nm:>3} ";
            line-numbers-right-format = "{np:>3} ";
          };
          side-by-side = {
            line-numbers-left-format = "{nm:>3} ";
            line-numbers-right-format = "│{np:>3} ";
          };
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

    programs.readline = {
      enable = true;
      variables = {
        editing-mode = "vim";
        show-mode-in-prompt = true;
        vi-cmd-mode-string = ''\1\e[2 q\2'';
        vi-ins-mode-string = ''\1\e[0 q\2'';
      };
    };

    home.shellAliases = {
      man = "${pkgs.bat-extras.batman}/bin/batman";
      ":q" = "exit";
    }
    // (optionalAttrs hasRebuildCommand {
      rebuild-reboot = "rebuild -t boot && reboot";
      rebuild-test = "rebuild -t test";
      rebuild-poweroff = "rebuild -t boot --timeout 10 ; poweroff";
      rebuild-gc-poweroff = "rebuild -t boot --timeout 10 && nix-collect-garbage --delete-older-than 14d ; poweroff";
    });
    programs.bash = {
      enable = true;
      historyControl = [ "ignorespace" "erasedups" ];
      initExtra = ''
      historyIgnore = [ "exit" "?" "??" ];
        alias bathelp='bat --plain --language=help'
        function help() {
          "$@" --help 2>&1 | bathelp
        }
        function h() {
          "$@" -h 2>&1 | bathelp
        }

        alias batpage='bat --style=plain --paging=always'
        function page() {
          "$@" | batpage
        }

        function ezap() {
          eza --colour=always --icons=always "$@" | batpage --pager="less -r"
        }

        function nixrun() (
          if [ "$1" = "-u" ]; then
            shift 1
            unstable="-unstable"
          fi
          nix run "nixpkgs''${unstable}#$1" -- "''${@:2}"
        )
        function nixshell() (
          if [ "$1" = "-u" ]; then
            shift 1
            unstable="-unstable"
          fi
          nix shell "nixpkgs''${unstable}#$1" "''${@:2}"
        )

        function nixrepl-system() (
          nix repl \
            --override-flake flake "''${1-$NIXOS_BUILD_DIR}" \
            --expr '
              let
                hostconfig = (__getFlake "flake").nixosConfigurations.'"$NIXOS_BUILD_CONFIGURATION"';
              in
              # pass inputs that would be available to a module
              {
                inherit (hostconfig) config options pkgs;
                inherit (hostconfig._module) specialArgs;
              } // hostconfig._module.specialArgs
            '
        )

        function realwhich() {
          realpath $(which "$@")
        }

        function rgdiff() {
          # these will break if '--' is passed
          # but swapping the order will break them if '-C3', etc. are passed
          # so idk
          rg "$@" -l |
          while read -r file; do
            rg "$@" --passthru -- "$file" |
            # labels to prevent a filename of '-' from stdin
            diff -L "a/$file" -L "b/$file" -u "$file" -
            # add whitespace between diffs for viewing pleasure
            echo
          done
        }
        function rgr() {
          rgdiff "$@" | patch -p1
        }

        function keepsudo() {
          sudo -v && {
            while
              sleep ''${1:-240} &&
              sudo -v
            do true
            done &
          }
        }
      '';
    };

    home.sessionVariables = {
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
        # stores transient state that could be removed without
        # too much issue (undos, swaps, shada, etc.)
        ".local/state/nvim"
        # stores more permanent state that should not be
        # removed so easily (sessions, etc.)
        ".local/share/nvim"
        ".config/sops"
        ".config/syncthing"
        ".local/state/lazygit"
      ] ++ lists.optionals desktop [
        ".config/GitHub Desktop"
        ".config/Code"
        ".vscode"
      ] ++ lists.optionals personal-gaming [
        "Pictures"
        "Videos"
        "Music"
        "Downloads"
        "Saves"
        "Torrents"
        ".config/vesktop"
        ".config/google-chrome"
        # cache for logged in accounts and stuff
        ".cache/google-chrome"
        ".local/share/Steam"
        ".config/termusic"
        ".config/qBittorrent"
      ];
    };
  })

  (attrsets.optionalAttrs (desktop) {
    home.packages = with pkgs; [
      (google-chrome.override {
        commandLineArgs = "--incognito";
      })
      github-desktop
      nvtopPackages.full
      mpv
      unstable.neovide
    ];

    services.wlsunset = {
      enable = true;
      # they are in fact not allowed to be identical :/
      temperature.day = 4501;
      temperature.night = 4500;
      # i do not care but they have to be set
      latitude = "";
      longitude = "";
    };

    home.sessionVariables = {
      TERMINAL = "kitty";
    };

    programs.kitty = {
      enable = true;
      shellIntegration.mode = "no-cursor";
      settings = {
        dynamic_background_opacity = true;
        allow_remote_control = true;
      };
    };

    programs.vscode = {
      enable = true;
      package = pkgs.unstable.vscodium.fhs;
    };

    home.pointerCursor = {
      name = "Win10OS-cursors";
      size = 24;
      package = pkgs.local.Win10OS-cursors;
    };
  })

  (attrsets.optionalAttrs (personal-gaming) (
  let
    declareDefault = name: default: ''${name}="''${${name}:-${default}}"'';
    declare-LINKED_SAVES_DIR = declareDefault "LINKED_SAVES_DIR" "$HOME/Saves";
    declare-LINKED_SAVES_LIST = declareDefault "LINKED_SAVES_LIST" "$LINKED_SAVES_DIR/list.json";

    jq = pkgs.jq + "/bin/jq";
    xargs = pkgs.findutils + "/bin/xargs";
    sponge = pkgs.moreutils + "/bin/sponge";

    linkSaveDir = lib.scripts.mkScript pkgs "linkSaveDir" ''
      ${declare-LINKED_SAVES_DIR}

      test -n "$1" || {
        >&2 echo 'the save location must be passed as the first parameter'
        exit 1
      }
      test -n "$2" || {
        >&2 echo 'the save name must be passed as the second parameter'
        exit 1
      }
      save_dir="$(realpath -s "$1")"
      save_name="$2"
      linked_save_dir="''${LINKED_SAVES_DIR}/''${save_name}"

      function ifnotquiet() {
        test ! -n "$LINK_SAVE_QUIET" && "$@"
      }

      current_linked_dir="$(readlink "$save_dir")" &&
      test "$current_linked_dir" = "$linked_save_dir" && {
        ifnotquiet echo "'$save_dir' already correctly linked to '$linked_save_dir'"
        exit 0
      }

      # check if no file exists then make parent directories
      # or if it is an empty directory then delete it
      function ensureAvailable() {
        {
          test ! -e "$1" &&
          mkdir -p "$(dirname "$1")"
        } || {
          test -n "$(find "$1" -maxdepth 0 -empty)" &&
          rmdir "$1"
        }
      }

      if ensureAvailable "$save_dir"; then
        ifnotquiet echo "'$save_dir' empty..."
        mkdir -p "$linked_save_dir"
      elif ensureAvailable "$linked_save_dir"; then
        ifnotquiet echo "'$save_dir' not empty but '$linked_save_dir' is so moving the former to the latter..."
        mv -T "$save_dir" "$linked_save_dir"
      else
        # even if quiet
        echo "files present in both normal dir ('$save_dir') and linked dir ('$linked_save_dir')"
        echo "backing up the linked files and using the normal ones"
        mv --backup=numbered -T "$save_dir" "$linked_save_dir"
      fi
      ln -s -T "$linked_save_dir" "$save_dir" &&
      ifnotquiet echo "successfully linked '$save_dir' to '$linked_save_dir'"
    '';
    linkSaveDirs = lib.scripts.mkScript pkgs "linkSaveDirs" ''
      ${declare-LINKED_SAVES_DIR}
      ${declare-LINKED_SAVES_LIST}

      test ! -e "$LINKED_SAVES_LIST" && {
        test ! -n "$LINK_SAVE_QUIET" && echo "linked saves list ('$LINKED_SAVES_LIST') not found"
        exit 0
      }

      cat "$LINKED_SAVES_LIST" |
      ${jq} --raw-output0 '
        to_entries .[] |
        (.value, .key)
      ' |
      ${xargs} -0 -L2 ${linkSaveDir}
    '';
    addLinkedSave = lib.scripts.mkScript pkgs "addLinkedSave" ''
      ${declare-LINKED_SAVES_DIR}
      ${declare-LINKED_SAVES_LIST}

      test -n "$1" || {
        >&2 echo 'the save location must be passed as the first parameter'
        exit 1
      }
      save_dir="$(realpath -s "$1")"
      save_name="''${2:-$(basename "$save_dir")}"

      test ! -e "$LINKED_SAVES_LIST" && echo '{}' >"$LINKED_SAVES_LIST"

      cat "$LINKED_SAVES_LIST" |
      ${jq} --arg name "$save_name" --arg dir "$save_dir" '
        . += {$name: $dir}
      ' | ${sponge} "$LINKED_SAVES_LIST"

      ${linkSaveDir} "$save_dir" "$save_name"
    '';
  in
  {
    home.packages = with pkgs; [
      vesktop
      termusic
      qbittorrent
      linkSaveDir
      linkSaveDirs
      addLinkedSave
    ];

    home.activation.linkSaves = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ${linkSaveDirs}
    '';
  }))
];
}
