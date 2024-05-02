{ config, system-config, lib, pkgs, inputs, ... }:

{
  wayland.windowManager.hyprland = {
    settings = {
      monitor = ",preferred,auto,1";

      general = {
        gaps_in = 0;
        gaps_out = 0;
        border_size = 1;
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";

        no_cursor_warps = true;

        layout = "dwindle";

        # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
        allow_tearing = false;
      };

      input = {
        kb_layout = system-config.services.xserver.layout;
        kb_variant = system-config.services.xserver.xkbVariant;

        follow_mouse = 2;
        mouse_refocus = false;

        touchpad = {
          natural_scroll = true;
        };
        sensitivity = 0; # -1.0 - 1.0, 0 means no modification.
      };

      decoration = {
        rounding = 0;

        blur = {
          enabled = false;
          size = 3;
          passes = 1;
        };

        drop_shadow = true;
        shadow_range = 4;
        shadow_render_power = 3;
        "col.shadow" = "rgba(1a1a1aee)";
      };

      animations = {
        enabled = true;

        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";

        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };
      master = {
        new_is_master = true;
      };

      gestures = {
        workspace_swipe = false;
      };

      misc = {
        force_default_wallpaper = -1;
        disable_hyprland_logo = true;
        hide_cursor_on_key_press = true;
      };
    };
  };
}
