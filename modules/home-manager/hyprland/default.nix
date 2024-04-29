{ disable-touchpad, ... }@home-inputs:

{ config, system-config, lib, pkgs, inputs, ... }:

with lib; {
  imports = [ ./main-settings.nix ./binds.nix ]
    ++ lists.optional (disable-touchpad != null) (import ./toggle-touchpad.nix disable-touchpad);

  home.packages = with pkgs; [
    kitty

    rofi-wayland

    mako
    libnotify
  ];
  # Optional, hint electron apps to use wayland:
  # environment.sessionVariables.NIXOS_OZONE_WL = "1";

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome.gnome-themes-extra;
    };
    gtk3.extraConfig = {
      Setting = ''
        gtk-application-prefer-dark-theme=1
      '';
    };
    gtk4.extraConfig = {
      Setting = ''
        gtk-application-prefer-dark-theme=1
      '';
    };
  };

  programs.waybar = {
    enable = true;
    systemd.enable = true;
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = system-config.programs.hyprland.finalPackage;
    plugins = [
      inputs.hycov.packages.${pkgs.system}.hycov
    ];
    settings = with pkgs; {

      env = (attrsets.mapAttrsToList (
          name: value: name + "," + builtins.toString value
        ) config.home.sessionVariables)
      ++ [
      ];
    };
  };
}
