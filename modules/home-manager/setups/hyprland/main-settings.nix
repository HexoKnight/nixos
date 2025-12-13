{ lib, nixosConfig, ... }:

{
  wayland.windowManager.hyprland = {
    settings = {
      monitor = [
        ",preferred,auto,1"
      ];

      general = {
        gaps_in = 0;
        gaps_out = 0;
        border_size = 1;
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";

        layout = "dwindle";

        # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
        allow_tearing = false;
      };

      input = {
        kb_layout = nixosConfig.services.xserver.xkb.layout;
        kb_variant = nixosConfig.services.xserver.xkb.variant;

        follow_mouse = 2;
        mouse_refocus = false;

        touchpad = {
          natural_scroll = true;
        };
        sensitivity = 0; # -1.0 - 1.0, 0 means no modification.
      };

      cursor = {
        no_warps = true;
        hide_on_key_press = true;
      };

      decoration = {
        rounding = 0;

        blur = {
          enabled = false;
          size = 3;
          passes = 1;
        };

        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };
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

      layerrule = [
        # fix borders in screenshots (due to the selection getting caught in the screenshot)
        "noanim, selection"
        "noanim, hyprpicker"
      ];

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      misc = {
        force_default_wallpaper = -1;
        disable_hyprland_logo = true;
        mouse_move_focuses_monitor = false;
      };
    };
  };

  xdg.configFile."hypr/xdph.conf".text = lib.hm.generators.toHyprconf {
    attrs = {
      screencopy = {
        allow_token_by_default = true;
      };
    };
  };
}
