{ lib, nixosConfig, ... }:

{
  wayland.windowManager.hyprland = {
    settings.monitor = [
      {
        output = "";
        mode = "preferred";
        position = "auto";
        scale = 1;
      }
    ];
    settings.config = {
      general = {
        gaps_in = 0;
        gaps_out = 0;
        border_size = 1;
        col.active_border.colors = [
          "rgba(33ccffee)"
          "rgba(00ff99ee)"
        ];
        col.active_border.angle = 45;
        col.inactive_border = "rgba(595959aa)";

        layout = "dwindle";
      };

      input = {
        kb_layout = nixosConfig.services.xserver.xkb.layout;
        kb_variant = nixosConfig.services.xserver.xkb.variant;

        follow_mouse = 2;
        mouse_refocus = false;

        sensitivity = 0; # -1.0 - 1.0, 0 means no modification.

        touchpad = {
          natural_scroll = true;
        };
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
      };

      dwindle = {
        preserve_split = true;
      };

      misc = {
        force_default_wallpaper = -1;
        disable_hyprland_logo = true;
        mouse_move_focuses_monitor = false;
      };
    };
    settings.curve = [
      {
        _args = [
          "myBezier"
          {
            type = "bezier";
            points = [
              [
                0.05
                0.9
              ]
              [
                0.1
                1.05
              ]
            ];
          }
        ];
      }
    ];
    settings.animation = [
      {
        leaf = "windows";
        enabled = true;
        speed = 7;
        bezier = "myBezier";
      }
      {
        leaf = "windowsOut";
        enabled = true;
        speed = 7;
        bezier = "default";
        style = "popin 80%";
      }
      {
        leaf = "border";
        enabled = true;
        speed = 1;
        bezier = "default";
      }
      {
        leaf = "borderangle";
        enabled = true;
        speed = 8;
        bezier = "default";
      }
      {
        leaf = "fade";
        enabled = true;
        speed = 7;
        bezier = "default";
      }
      {
        leaf = "workspaces";
        enabled = true;
        speed = 6;
        bezier = "default";
      }
    ];

    settings.layer_rule = [
      # fix borders in screenshots (due to the selection getting caught in the screenshot)
      {
        match.namespace = "selection";
        no_anim = true;
      }
      {
        match.namespace = "hyprpicker";
        no_anim = true;
      }
    ];
  };

  xdg.configFile."hypr/xdph.conf".text = lib.hm.generators.toHyprconf {
    attrs = {
      screencopy = {
        allow_token_by_default = true;
      };
    };
  };
}
