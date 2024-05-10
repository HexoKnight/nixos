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
        "$mainMod CTRL ALT, XKB_KEY_Delete, exit, "
        "$mainMod, E, exec, lf"
        "$mainMod, V, togglefloating, "
        "$mainMod, R, exec, rofi -show run"
        "$mainMod SHIFT, R, exec, rofi -show drun"
        "$mainMod, P, pseudo, "
        "$mainMod, S, layoutmsg, togglesplit"

        ''$mainMod SHIFT, S, exec, ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)"''

        "$mainMod, M, focusmonitor, +1"
        "$mainMod SHIFT, M, movecurrentworkspacetomonitor, +1"

        # Example special workspace (scratchpad)
        # "$mainMod, S, togglespecialworkspace, magic"
        # "$mainMod SHIFT, S, movetoworkspace, special:magic"

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

      ++ (builtins.concatMap (directionList: with with lib; builtins.listToAttrs
        ((lists.zipListsWith attrsets.nameValuePair) ["arrowKey" "homeKey" "hyprDir"] directionList);
        builtins.concatMap (key: [
          "$mainMod, ${key}, movefocus, ${hyprDir}"
        ]) [arrowKey homeKey]
      ) [
        ["left"  "h" "l"]
        ["down"  "j" "d"]
        ["up"    "k" "u"]
        ["right" "l" "r"]
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
