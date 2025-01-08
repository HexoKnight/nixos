{ lib, pkgs, config, nixosConfig, ... }:

let
  inherit (lib) mkOption mkEnableOption;

  mkListIf = condition: value: [ (lib.mkIf condition value) ];

  mkBoolOption = msg: lib.mkOption {
    description = "Whether ${msg}.";
    type = lib.types.bool;
    default = false;
  };

  cfg = config.setups;

  inherit (cfg.config) username;

  homeDirectory = "/home/" + username;
in
{
  imports = [
    ./neovim
    ./fzf.nix
    ./trash.nix
    ./google-chrome.nix
    ./rclone.nix
    ./rust.nix
    ./btop.nix
    ./jupyter
    ./android.nix
    ./mpv.nix

    ./plasma.nix
    ./hyprland
  ];

  options.setups = {
    config = {
      username = mkOption {
        description = "The user's username.";
        type = lib.types.nonEmptyStr;
      };

      disable-touchpad = mkOption {
        description = "The name (`hyprctl devices | grep touchpad`) of the touchpad to disable.";
        type = lib.types.nullOr lib.types.nonEmptyStr;
        default = null;
      };
    };

    normal = mkEnableOption "the normal setup" // { default = cfg.desktop; };

    impermanence = mkEnableOption "impermanence";

    desktop = mkBoolOption "the user should have a desktop" // { default = cfg.personal-gaming; };

    personal-gaming = mkBoolOption "the user should have personal/gaming stuff";
  };

  options = {
    home-inputs = mkOption {
      type = lib.types.attrsOf lib.types.anything;
      readOnly = true;
      default = cfg;
    };
  };

  config = lib.mkMerge (
    mkListIf cfg.normal {
      home = { inherit username homeDirectory; };
      nix.settings.use-xdg-base-directories = true;

      nixpkgs.overlays = nixosConfig.nixpkgs-overlays;
      nixpkgs.allowUnfreePkgs = [
        "google-chrome"
        (pkg: builtins.elem pkg.meta.license.shortName [
          "CUDA EULA"
        ])
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
        acpi
        ssh-to-age
        compsize

        # programs
        lf
        fd
        ripgrep
        jq
        neovim-remote
        local.batman
        local.nixos

        # build tools
        nixVersions.nix_2_19
      ];

      programs.nix-index-database.comma.enable = true;
      programs.nix-index.enableBashIntegration = false;

      programs.man.generateCaches = true;
      programs.info.enable = true;

      programs.bat = {
        enable = true;
      };

      programs.eza = {
        enable = true;
        icons = "auto";
      };

      setups = {
        neovim.enable = true;
        fzf.enable = true;
        trash.enable = true;
        rclone.enable = true;
        btop.enable = true;
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
            open = "nvr -s -c 'set readonly' --remote {{filename}}";
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
          git = {
            # can apparently cause issues but seems fine
            overrideGpg = true;
            paging.pager = "delta --paging=never";
          };
          customCommands = [
            {
              key = "<c-a>";
              context = "commits";
              description = "git rebase --committer-date-is-author-date ...";
              # extra options mostly from lazygit's own rebase commands
              command = "git rebase --autostash --keep-empty --no-autosquash --rebase-merges --committer-date-is-author-date {{.SelectedLocalCommit.Hash}}^";
              showOutput = true;
            }
          ];
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
            fetch.prune = true;

            commit.gpgSign = true;
            gpg.format = "ssh";
            user.signingKey = "~/.ssh/id_ed25519.pub";
          };
        };

        delta = {
          enable = true;
          options = {
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
        addKeysToAgent = "yes";
        matchBlocks = {
          "github.com" = {
            forwardAgent = true;
          };
          homeserver = {
            user = "nixos";
            hostname = "ssh.bruhpi.uk";
            port = 22;
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
        rebuild-reboot = "nixos build --boot && reboot";
        rebuild-test = "nixos build --switch";
        rebuild-poweroff = "nixos build --boot --timeout 10 ; poweroff";
        rebuild-gc-poweroff = "nixos build --boot --timeout 10 && nix-collect-garbage --delete-older-than 14d ; poweroff";
      };
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
          eztat() {
            eza --long --tree --level=0 --sort=none "$@"
          }

          u() { NIXPKGS_FLAKE=nixpkgs-unstable "$@"; }

          nixrun() {
            nix run "''${NIXPKGS_FLAKE:-nixpkgs}#$1" -- "''${@:2}"
          }
          nixrun-u() { u nixrun "$@"; }
          nixshell() {
            nix shell "''${NIXPKGS_FLAKE:-nixpkgs}#$1" "''${@:2}"
          }
          nixshell-u() { u nixshell "$@"; }

          nixrun-sudo() {
            nixshell "$1" -c sudo "$1" "''${@:2}"
          }

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

          line() {
            sed -En "''${1}p"
          }

          realwhich() {
            realpath $(which "$@")
          }
          batwhich() {
            bat $(which "$@")
          }

          getmountof() {
            df --output=target "$1" | sed 1d | xargs -L1 findmnt
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
        # fixes git paging:
        # stackoverflow.com/a/74047582
        LESS = "";
      };
      home.sessionPath = [
        "$HOME/.local/bin"
      ];

      # Let Home Manager install and manage itself.
      programs.home-manager.enable = true;
    } ++
    mkListIf cfg.impermanence {
      persist-home = {
        enable = true;
        directories = [
          "Documents"
          "Downloads"
          ".nixos"
          ".ssh"
          ".config/sops"
          ".config/syncthing"
          ".local/state/lazygit"
          ".local/bin"
        ];
      };
    } ++
    mkListIf cfg.desktop {
      home.packages = with pkgs; [
        nvtopPackages.full
      ];

      setups.mpv.enable = true;

      setups.google-chrome.enable = true;

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
          scrollback_fill_enlarged_window = true;
        };
      };

      home.pointerCursor = {
        name = "Win10OS-cursors";
        size = 24;
        package = pkgs.local.Win10OS-cursors;
      };
    } ++
    mkListIf cfg.personal-gaming {
      persist-home = {
        directories = [
          "Pictures"
          "Videos"
          "Music"
          "Saves"
          "Torrents"
          ".config/vesktop"
          ".local/share/Steam"
          ".config/termusic"
          ".config/qBittorrent"
          ".local/share/qBittorrent"
        ];
      };

      home.packages = with pkgs; [
        vesktop
        termusic
        qbittorrent

        prismlauncher

        local.mklink
        local.linkSaveDirs
        local.addLinkedSave
      ];

      steam-presence.enable = true;

      home.activation.linkSaves = lib.hm.dag.entryAfter ["writeBoundary"] ''
        $DRY_RUN_CMD ${lib.getExe pkgs.local.linkSaveDirs}
      '';
    }
  );
}
