{ username, persistence, desktop, personal-gaming, disable-touchpad, hasRebuildCommand, ... }@home-inputs:

{ config, lib, pkgs, inputs, nixosConfig, ... }:

with lib;
let
  homeDirectory = "/home/" + username;
in {
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
    inputs.nix-index-database.hmModules.nix-index
    ./neovim
    ./fzf.nix
  ] ++ lists.optionals desktop [
    # ./plasma.nix
    ./hyprland
  ];

  options = {
    home-inputs = mkOption {
      type = types.attrsOf types.anything;
      readOnly = true;
      default = home-inputs;
    };
  };

  config = mkMerge [{
    home = { inherit username homeDirectory; };

    nixpkgs.overlays = nixosConfig.nixpkgs-overlays;
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
      local.batman

      nixVersions.nix_2_19

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
    programs.nix-index.enableBashIntegration = false;

    programs.man.generateCaches = true;
    programs.info.enable = true;

    programs.bat = {
      enable = true;
      extraPackages = with pkgs.bat-extras; [
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
      "info" = "info --vi-keys";
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
      historyIgnore = [ "exit" "?" "??" ];
      initExtra = /* bash */ ''
        alias bathelp='bat --plain --language=help'
        help() {
          "$@" --help | bathelp
        }
        h() {
          "$@" -h | bathelp
        }

        alias batpage='bat --style=plain --paging=always'
        page() {
          "$@" | batpage
        }

        ezap() {
          eza --colour=always --icons=always "$@" | batpage --pager="less -r"
        }

        u() { NIXPKGS_FLAKE=nixpkgs-unstable "$@"; }

        nixrun() (
          nix run "''${NIXPKGS_FLAKE:-nixpkgs}#$1" -- "''${@:2}"
        )
        nixrun-u() { u nixrun "$@"; }
        nixshell() (
          nix shell "''${NIXPKGS_FLAKE:-nixpkgs}#$1" "''${@:2}"
        )
        nixshell-u() { u nixshell "$@"; }

        nixman() (
          # WTF idek..: nix shell nixpkgs#texliveInfraOnly.man -c env man --path texhash

          dot_section=""
          case "$1" in
            *\(*\))
              manual=''${1%(*)}
              section=''${1#"$manual"}
              section=''${section#(}
              section=''${section%)}
            ;;
            *.*)
              dot_section=1
              manual=''${1%.*}
              section=''${1#"$manual"}
              section=''${section#.}
            ;;
            *)
              manual=$1
              section=""
            ;;
          esac
          section_first_char=''${section%"''${section#?}"}

          if [ -n "$dot_section" ]; then
            # dot might be part of name rather than section
            # eg. `man python3.12` == `man python3.12.1` == `man python3.12(1)`
            section_regex=''${section:+"$section(\.[0-9a-z]+)?"}
            section_regex=''${section_regex:-[0-9a-z]+}
          else
            section_regex=''${section:-[0-9a-z]+}
          fi
          section_first_char_regex=''${section_first_char:-[0-9a-z]}

          export fullregex="/share/man/man$section_first_char_regex/$manual\.$section_regex(\.[^.]+)?"
          export manual

          pkg=$(${config.lib.fzf.genFzfCommand {
            defaultCommand = /* bash */ ''
              nix-locate --whole-name --at-root --regex "$fullregex" |
              # what the fuck
              sed -Ee 's|(\S+).*/nix/store/.{32}-(.*)/share/man/man./'"$manual"'\.([^.])(\.[^.]+)?|start=$(printf "%-20s - " "\1 (\3)"); printf "%s%*s" "$start" "$((43 - ''${#start}))" "\2"|e'
            '';
            binds.enter.become = "printf %s {1} | tr -d '()'";
            options = {
              delimiter = "\\s+";
              exit-0 = true;
            };
          }}) || {
            if [ "$?" -eq 1 ]; then
              >&2 echo "No manual entry for $1"
            else
              >&2 echo "package-choosing failed"
            fi
            return 1
          }

          pkgexpr="''${NIXPKGS_FLAKE:-nixpkgs}#$pkg"

          # hope multiple out paths are never produced (whcih SHOULD be impossible...)
          manpath=$(nix build "$pkgexpr" --no-link --print-out-paths)
          nix shell "$pkgexpr" -c env MANPATH="$manpath/share/man" man "$1"
        )
        nixman-u() { u nixman "$@"; }

        nixrepl-system() (
          nix repl \
            --override-flake flake "''${1-$NIXOS_BUILD_DIR}" \
            --expr '
              let
                hostconfig = (__getFlake "flake").nixosConfigurations."'"$NIXOS_BUILD_CONFIGURATION"'";
              in
              # pass inputs that would be available to a module
              {
                inherit (hostconfig) config options pkgs;
                inherit (hostconfig._module) specialArgs;
              } // hostconfig._module.specialArgs
              # plus some home-manager stuff
              // {
                hmConfig = hostconfig.config.home-manager.users."'"$USER"'";
              }
            '
        )

        realwhich() {
          realpath $(which "$@")
        }

        rgdiff() {
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
        rgr() {
          rgdiff "$@" | patch -p1
        }

        man() (
          test "$#" -gt 0 && exec env man "$@"

          ${config.lib.fzf.genFzfCommand {
            defaultCommand = "man -k .";
            binds.enter.become = "man {1}{2}";
            options = {
              preview = "man {1}{2}";
              delimiter = "\\s+";
              exit-0 = true;
              height = "~20";
            };
          }} || {
            if [ "$?" -eq 1 ]; then
              >&2 echo "No manuals found"
            else
              >&2 echo "manpage-choosing failed"
            fi
            return 1
          }
        )

        keepsudo() {
          sudo -v && {
            while
              sleep ''${1:-240} &&
              sudo -v
            do true
            done &
          }
        }

        nix-locate-bin() {
          nix-locate --minimal --no-group --type x --type s --top-level --whole-name --at-root "/bin/$1"
        }
        nix-locate-choose-bin() {
          nix-locate-bin "$@" | fzf -0
        }

        command_not_found_handle() {
          package=$(nix-locate-choose-bin "$@") || {
            if [ "$?" -eq 1 ]; then
              >&2 echo "bash: $1: command not found"
            else
              >&2 echo "bash: $1: package-choosing failed"
            fi
            return 1
          }
          bin_path=$(nix build --no-link --print-out-paths nixpkgs#"$package")/bin/$1 &&
          add_to_local_path "$bin_path" "$1" &&
          exec "$@"
        }

        add_to_local_path() {
          ln -sfT "$1" "$BASH_LOCAL_PATH/''${2:-$(basename "$1")}"
        }
        remove_from_local_path() {
          test -d "$BASH_LOCAL_PATH" &&
          rm "$BASH_LOCAL_PATH/$1"
        }

        # on most systems, $XDG_RUNTIME_DIR is tmpfs
        export BASH_LOCAL_PATH="''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}}/bash-local-path/$$"
        mkdir -p "$BASH_LOCAL_PATH"
        export PATH="$BASH_LOCAL_PATH:$PATH"

        _remove_local_path() {
          test -d "$BASH_LOCAL_PATH" &&
          case "$BASH_LOCAL_PATH" in *$$)
            # an `rm -rf` like this could be bad but
            # this level of tamper protection
            # is probably enough...
            rm -rf "$BASH_LOCAL_PATH"
          esac
        }

        trap _remove_local_path EXIT
      '';
    };

    home.sessionVariables = {
      MANPAGER = "batman";
    };

    # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;
  }

  (attrsets.optionalAttrs persistence {
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

  (attrsets.optionalAttrs desktop {
    home.packages = with pkgs; [
      (google-chrome.override {
        commandLineArgs = [
          "--incognito"
          "--enable-blink-features=MiddleClickAutoscroll"

          # can't get hardware acceleration to work :/
          # https://wiki.archlinux.org/title/Chromium#Hardware_video_acceleration
          # "--enable-features=VaapiVideoDecodeLinuxGL"
          # "--ignore-gpu-blocklist"
          # "--enable-zero-copy"

          # so forcing xwayland
          "--ozone-platform=x11"
          # dunno if webgpu is really necessary
          "--enable-unsafe-webgpu"
        ];
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

  (attrsets.optionalAttrs personal-gaming {
    home.packages = with pkgs; [
      vesktop
      termusic
      qbittorrent

      prismlauncher

      local.mklink
      local.linkSaveDirs
      local.addLinkedSave
    ];

    home.activation.linkSaves = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ${lib.getExe pkgs.local.linkSaveDirs}
    '';
  })
];
}
