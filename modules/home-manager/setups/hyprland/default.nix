{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.setups.hyprland;
in
{
  imports = [
    ./audio.nix
    ./binds.nix
    ./kb-mouse.nix
    ./main-settings.nix
    ./options.nix
    ./polkit-agent.nix
    ./toggle-touchpad.nix
    ./workspaces.nix
  ];

  options.setups.hyprland = {
    enable = lib.mkEnableOption "hyprland configuration";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.mako
      pkgs.libnotify

      pkgs.wl-clipboard-rs
    ];
    # Optional, hint electron apps to use wayland:
    home.sessionVariables.NIXOS_OZONE_WL = "1";

    persist-home.directories = [
      # otherwise hyprland shows update info every boot
      ".local/share/hyprland"
    ];

    shikane.enable = true;

    services.swayosd = {
      enable = true;
      # https://github.com/ErikReider/SwayOSD/blob/main/data/style/style.scss
      stylePath = pkgs.writeText "swayosd-style" ''
        #osd {
          background: alpha(@theme_bg_color, 0.8);
        }
      '';
    };

    programs.tofi = {
      enable = true;
      settings = {
        font = "${pkgs.nerd-fonts.roboto-mono}/share/fonts/truetype/NerdFonts/RobotoMono/RobotoMonoNerdFontMono-Regular.ttf";

        border-width = 0;
        outline-width = 0;

        width = "100%";
        height = "100%";
        padding-top = "16%";
        padding-bottom = "16%";
        padding-left = "16%";
        # padding-right = "16%";

        background-color = "#000A";
      };
      package = pkgs.tofi.overrideAttrs (
        finalAttrs: prevAttrs: {
          version = "unstable-2024-10-30";

          # latest main adds functionality like:
          # - exit code 1 on failure
          # - `--print-index`
          src = pkgs.fetchFromGitHub {
            owner = "philj56";
            repo = "tofi";
            rev = "1eb6137572ab6c257ab6ab851d5d742167c18120";
            hash = "sha256-OD56rwDrXgb5pg85sT5v+zl9A1/sfn77PBSG4gT76bE=";
          };

          patches = prevAttrs.patches or [ ] ++ [
            # PR adds `--drun-print-desktop`
            (pkgs.fetchpatch2 {
              url = "https://patch-diff.githubusercontent.com/raw/philj56/tofi/pull/214.patch";
              hash = "sha256-2PhEy8ASE0V3D5k5e1ewrvJnYB9QccsNiN7j87tzIZA=";
            })
          ];
        }
      );
    };

    programs.eww = {
      enable = true;
      package = pkgs.eww;
      systemd.enable = true;

      scssConfig = null;
      yuckConfig = null;
    };
    xdg.configFile = {
      "eww/eww.scss".source = ./eww/eww.scss;
      "eww/eww.yuck".source = pkgs.replaceVars ./eww/eww.yuck {
        monitorconnection = lib.getExe (
          pkgs.writeShellApplication {
            name = "monitorconnection";
            text = lib.readFile ./eww/scripts/monitorconnection;
            runtimeInputs = [
              pkgs.jc
              pkgs.jq
              pkgs.moreutils
            ];
          }
        );
        monitormusic = lib.getExe (
          pkgs.writeShellApplication {
            name = "monitormusic";
            text = lib.readFile ./eww/scripts/monitormusic;
            runtimeInputs = [
              pkgs.playerctl
            ];
          }
        );
        monitorvolume = lib.getExe (
          pkgs.writeShellApplication {
            name = "monitorvolume";
            text = lib.readFile ./eww/scripts/monitorvolume;
            excludeShellChecks = [
              # shellcheck doesn't like the '..$0..'
              "SC2016"
            ];
            runtimeInputs = [
              pkgs.jq
              pkgs.pulseaudio
              pkgs.pamixer
            ];
          }
        );
      };
    };

    gtk = {
      enable = true;
      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
    };
    qt = {
      enable = true;
      platformTheme.name = "gtk3";
      style.name = "adwaita-dark";
    };

    dconf.settings."org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };

    # fix for 'No GSettings schemas are installed on the system'
    # that occurs with some (ironically) qt apps
    home.sessionVariables.GSETTINGS_SCHEMA_DIR = "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}/glib-2.0/schemas";

    wayland.windowManager.hyprland = {
      enable = true;
      plugins = [ ];
      events = {
        "hyprland.start" = { }: [
          (lib.mkLuaInline "hl.exec_cmd([[${lib.getExe config.programs.eww.package} open-many bar0 bar1]])")
          (lib.mkLuaInline "hl.exec_cmd([[vesktop]])")
          (lib.mkLuaInline "hl.exec_cmd([[steam]])")
        ];

        "config.reloaded" = { }: [
          (lib.mkLuaInline "hl.exec_cmd([[${lib.getExe' config.services.shikane.package "shikanectl"} reload]])")
        ];
      };
      settings = {
        window_rule = [
          {
            match.initial_class = "vesktop";
            workspace = "name:__discord silent";
          }
          {
            match.initial_class = "steam";
            workspace = "name:__steam silent";
          }
        ];

        # not sure if this is necessary
        env = (
          lib.attrsets.mapAttrsToList (name: value: {
            _args = [
              name
              (builtins.toString value)
            ];
          }) config.home.sessionVariables
        );
      };
    };
  };
}
