{ disable-touchpad, ... }@home-inputs:

{ config, system-config, lib, pkgs, inputs, ... }:

with lib; {
  imports = [
    ./main-settings.nix
    ./binds.nix
    ./workspaces.nix
    ./audio.nix
    ./hyprbinds.nix
  ] ++ lists.optional (disable-touchpad != null) (import ./toggle-touchpad.nix disable-touchpad);

  home.packages = with pkgs; [
    rofi-wayland

    mako
    libnotify
  ];
  # Optional, hint electron apps to use wayland:
  home.sessionVariables.NIXOS_OZONE_WL = "1";

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
    configDir = ./eww;
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome.gnome-themes-extra;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

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

      windowrulev2 = [
        "workspace name:__discord silent, initialtitle:(Discord)"
        "workspace name:__steam silent, initialclass:(steam)"

        "workspace name:__gvim, initialclass:(Gvim)"
        "workspace name:__github-desktop, initialclass:(GitHub Desktop)"
      ];

      env = (attrsets.mapAttrsToList (
          name: value: name + "," + builtins.toString value
        ) config.home.sessionVariables)
      ++ [
      ];
    };
  };
}
