{ config, system-config, lib, pkgs, inputs, ... }:

{
  wayland.windowManager.hyprland = {
    settings = with pkgs; {
      binds = {
        allow_workspace_cycles = true;
      };

      bindr = [
        "SUPER, grave, exec, hyprctl keyword input:follow_mouse 2"
      ];
      bind = [
        "SUPER, grave, exec, hyprctl keyword input:follow_mouse 1"

        "SUPER, Q, killactive, "
        "SUPER, T, exec, ${config.home.sessionVariables.TERMINAL}"
        "SUPER CTRL ALT, XKB_KEY_Delete, exit, "
        "SUPER, E, exec, lf"
        "SUPER, V, togglefloating, "
        "SUPER, R, exec, rofi -show run"
        "SUPER SHIFT, R, exec, rofi -show drun"
        "SUPER, P, pseudo, "
        "SUPER, S, layoutmsg, togglesplit"

        ''SUPER SHIFT, S, exec, ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)"''

        "SUPER, M, focusmonitor, +1"
        "SUPER SHIFT, M, movecurrentworkspacetomonitor, +1"

        # Example special workspace (scratchpad)
        # "SUPER, S, togglespecialworkspace, magic"
        # "SUPER SHIFT, S, movetoworkspace, special:magic"

        # Scroll through existing workspaces with mainMod + scroll
        "SUPER, mouse_down, workspace, e+1"
        "SUPER, mouse_up, workspace, e-1"

        # ALT-tab / SUPER-tab
        "SUPER, tab, workspace, previous"
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
        ((lists.zipListsWith attrsets.nameValuePair) ["arrowKey" "homeKey" "hyprDir" "resize"] directionList);
        builtins.concatMap (key: [
          "SUPER, ${key}, movefocus, ${hyprDir}"
          "SUPER SHIFT, ${key}, swapwindow, ${hyprDir}"
          "SUPER CTRL, ${key}, resizeactive, ${resize "10"}"
        ]) [arrowKey homeKey]
      ) [
        ["left"  "h" "l" (amount: "-${amount} 0")]
        ["down"  "j" "d" (amount: "0 ${amount}")]
        ["up"    "k" "u" (amount: "0 -${amount}")]
        ["right" "l" "r" (amount: "${amount} 0")]
      ])

      ++ builtins.concatLists (builtins.genList (
        x:
        let
          workspacenum = builtins.toString (x + 1);
          key = builtins.toString (if x == 9 then 0 else x + 1);
        in [
          # Switch workspaces with mainMod + [0-9]
          "SUPER, ${key}, workspace, ${workspacenum}"
          # Move active window to a workspace with mainMod + SHIFT + [0-9]
          "SUPER SHIFT, ${key}, movetoworkspace, ${workspacenum}"
        ]
      ) 10);

      bindm = [
        # Move/resize windows with mainMod + LMB/RMB and dragging
        "SUPER, mouse:272, movewindow"
        "SUPER, mouse:273, resizewindow"
      ];
    };
  };
}
