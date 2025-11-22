{ config, lib, pkgs, inputs, ... }:

with lib;
let
  inherit (config.home-inputs) disable-touchpad;

  cfg = config.setups.hyprland;
in {
  imports = [
    ./main-settings.nix
    ./binds.nix
    ./workspaces.nix
    ./audio.nix
    ./hyprbinds.nix
    ./toggle-touchpad.nix
    ./polkit-agent.nix
  ];

  options.setups.hyprland = {
    enable = lib.mkEnableOption "hyprland configuration";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      rofi-wayland

      mako
      libnotify

      wl-clipboard-rs
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
      settings = with pkgs; {
        exec-once = [
          (concatStringsSep " && " [
            "${config.programs.eww.package}/bin/eww daemon"
            "${config.programs.eww.package}/bin/eww open bar0"
            "${config.programs.eww.package}/bin/eww open bar1"
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

          "workspace name:__gvim, initialclass:(Gvim)"
        ];

        env = (attrsets.mapAttrsToList (
            name: value: name + "," + builtins.toString value
          ) config.home.sessionVariables)
        ++ [
        ];
      };
    };
  };
}
