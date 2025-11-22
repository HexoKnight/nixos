{ lib, pkgs, config, ... }:

let
  cfg = config.setups.hyprland;
in {
  imports = [
    ./audio.nix
    ./binds.nix
    ./hyprbinds.nix
    ./main-settings.nix
    ./polkit-agent.nix
    ./toggle-touchpad.nix
    ./workspaces.nix
  ];

  options.setups.hyprland = {
    enable = lib.mkEnableOption "hyprland configuration";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.rofi-wayland

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

    programs.eww = {
      enable = true;
      package = pkgs.eww;
      configDir = pkgs.runCommandLocal "eww-config" {} ''
        cp -rT ${./eww} $out

        chmod ug+w $out/scripts/*
        cp -fT ${pkgs.replaceVars ./eww/scripts/monitorconnection {
          inherit (pkgs) jc jq moreutils;
        }} $out/scripts/monitorconnection
        cp -fT ${pkgs.replaceVars ./eww/scripts/monitormusic {
          inherit (pkgs) playerctl;
        }} $out/scripts/monitormusic
        cp -fT ${pkgs.replaceVars ./eww/scripts/monitorvolume {
          inherit (pkgs) jq pulseaudio pamixer;
        }} $out/scripts/monitorvolume

        chmod +x $out/scripts/*
      '';
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
      plugins = [
        # inputs.hycov.packages.${pkgs.system}.hycov
      ];
      settings = {
        exec-once = [
          (lib.concatStringsSep " && " [
            "${lib.getExe config.programs.eww.package} daemon"
            "${lib.getExe config.programs.eww.package} open bar0"
            "${lib.getExe config.programs.eww.package} open bar1"
          ])
          "vesktop"
          "steam"
        ];

        exec = [
          "${lib.getExe' config.services.shikane.package "shikanectl"} reload"
        ];

        windowrulev2 = [
          "workspace name:__discord silent, initialtitle:(Discord)"
          "workspace name:__steam silent, initialclass:(steam)"
        ];

        env = (lib.attrsets.mapAttrsToList (
            name: value: name + "," + builtins.toString value
          ) config.home.sessionVariables)
        ++ [
        ];
      };
    };
  };
}
