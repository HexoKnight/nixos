{ config, system-config, lib, pkgs, inputs, ... }:

{
  wayland.windowManager.hyprland = {
    settings = with pkgs; {
      binds = {
        allow_workspace_cycles = true;
      };

      "$mainMod" = "SUPER";
      bindr = [
        "$mainMod, grave, exec, hyprctl keyword input:follow_mouse 2"
      ];
      bind = [
        "$mainMod, grave, exec, hyprctl keyword input:follow_mouse 1"

        "$mainMod, Q, killactive, "
        "$mainMod, T, exec, ${config.home.sessionVariables.TERMINAL}"
        "$mainMod, M, exit, "
        "$mainMod, E, exec, lf"
        "$mainMod, V, togglefloating, "
        "$mainMod, R, exec, rofi -show run"
        "$mainMod SHIFT, R, exec, rofi -show drun"

        "$mainMod, H, movefocus, l"
        "$mainMod, J, movefocus, d"
        "$mainMod, K, movefocus, u"
        "$mainMod, L, movefocus, r"

        # Example special workspace (scratchpad)
        "$mainMod, S, togglespecialworkspace, magic"
        "$mainMod SHIFT, S, movetoworkspace, special:magic"

        # Scroll through existing workspaces with mainMod + scroll
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"

        # ALT-tab / SUPER-tab
        "$mainMod, tab, workspace, previous"
        "ALT, tab, workspace, previous"
      ]

      ++ (let
        brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
      in [
        ", XF86KbdBrightnessUp,   exec, ${brightnessctl} -d *::kbd_backlight s +1"
        ", XF86KbdBrightnessDown, exec, ${brightnessctl} -d *::kbd_backlight s 1-"
        ", XF86MonBrightnessUp,   exec, ${brightnessctl} s +5%"
        ", XF86MonBrightnessDown, exec, ${brightnessctl} s 5%-"
      ])

      ++ (let
        swayosd = "${pkgs.swayosd}/bin/swayosd";
      in [
        ", XF86AudioRaiseVolume, exec, ${swayosd} --output-volume raise"
        ", XF86AudioLowerVolume, exec, ${swayosd} --output-volume lower"
        ", XF86AudioMute,        exec, ${swayosd} --output-volume mute-toggle"
      ])

      ++ builtins.concatLists (builtins.genList (
        x:
        let
          workspacenum = builtins.toString (x + 1);
          key = builtins.toString (if x == 9 then 0 else x + 1);
        in [
          # Switch workspaces with mainMod + [0-9]
          "$mainMod, ${key}, workspace, ${workspacenum}"
          # Move active window to a workspace with mainMod + SHIFT + [0-9]
          "$mainMod SHIFT, ${key}, movetoworkspace, ${workspacenum}"
        ]
      ) 10);

      bindm = [
        # Move/resize windows with mainMod + LMB/RMB and dragging
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];
    };
  };
}
