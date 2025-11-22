{ lib, pkgs, config, ... }:

{
  hyprbinds =
  let
    inherit (lib.hyprbinds)
      mkBind
      mkNoArgBind
      mkExec
      mkMouseBind

      # mergeFlags
      # addFlags
      withFlags
      repeating
      ;
  in
  lib.mkMerge [{
    "SUPER, grave" = [
      (mkExec "hyprctl keyword input:follow_mouse 1")
      (withFlags "r" mkExec "hyprctl keyword input:follow_mouse 2")
    ];
    "SUPER, Q" = mkNoArgBind "killactive";
    "SUPER, T" = mkExec config.home.sessionVariables.TERMINAL;
    "SUPER, B" = mkExec "x-www-browser";
    "SUPER CTRL ALT, XKB_KEY_Delete" = mkNoArgBind "exit";
    "SUPER, E" = mkExec "lf";
    "SUPER, R" = mkExec "rofi -show run";
    "SUPER SHIFT, R" = mkExec "rofi -show drun";

    "SUPER, P" = mkNoArgBind "pseudo";
    "SUPER, S" = mkBind "layoutmsg" "togglesplit";

    "SUPER, V" = mkNoArgBind "togglefloating";
    "SUPER, F" = mkBind "fullscreen" "0"; # proper fullscreen
    "SUPER SHIFT, F" = mkBind "fullscreen" "1"; # maximise
    "SUPER ALT, F" = mkBind "fullscreenstate" "2 0"; # fullscreen (but doesn't tell application)
    "SUPER CTRL, F" = mkBind "fullscreenstate" "0 2"; # only tells application that it is fullscreen

    "SUPER SHIFT, S" = mkExec ''${lib.getExe pkgs.grim} -g "$(${lib.getExe pkgs.slurp})"'';

    "SUPER, M" = mkBind "focusmonitor" "+1";
    "SUPER SHIFT, M" = mkBind "movecurrentworkspacetomonitor" "+1";

    # Example special workspace (scratchpad)
    # "SUPER, S" = mkBind "togglespecialworkspace" "magic";
    # "SUPER SHIFT, S" = mkBind "movetoworkspace" "special:magic";

    # Scroll through existing workspaces with mainMod + scroll
    "SUPER, mouse_down" = mkBind "workspace" "e+1";
    "SUPER, mouse_up" = mkBind "workspace" "e-1";

    # Move/resize windows with mainMod + LMB/RMB and dragging
    "SUPER, mouse:272" = mkMouseBind "movewindow";
    "SUPER, mouse:273" = mkMouseBind "resizewindow";

    # ALT-tab / SUPER-tab
    "SUPER, tab" = mkBind "workspace" "previous";
    "ALT, tab" = mkBind "workspace" "previous";
  }

  (let
    brightnessctl = lib.getExe pkgs.brightnessctl;
  in {
    ", XF86KbdBrightnessUp"   = mkExec "${brightnessctl} -d *::kbd_backlight s +1";
    ", XF86KbdBrightnessDown" = mkExec "${brightnessctl} -d *::kbd_backlight s 1-";
  })

  (let
    swayosd-client = lib.getExe' config.services.swayosd.package "swayosd-client";
  in {
    ", XF86MonBrightnessUp"   = repeating mkExec "${swayosd-client} --brightness +5";
    ", XF86MonBrightnessDown" = repeating mkExec "${swayosd-client} --brightness -5";

    ", XF86AudioRaiseVolume" = repeating mkExec "${swayosd-client} --output-volume +5";
    ", XF86AudioLowerVolume" = repeating mkExec "${swayosd-client} --output-volume -5";
    ", XF86AudioMute"        = mkExec "${swayosd-client} --output-volume mute-toggle";

    "SHIFT, XF86AudioRaiseVolume"  = repeating mkExec "${swayosd-client} --input-volume +5";
    "SHIFT, XF86AudioLowerVolume"  = repeating mkExec "${swayosd-client} --input-volume -5";
    "SHIFT, XF86AudioMute"         = mkExec "${swayosd-client} --input-volume mute-toggle";
  })

  (let
    mergeMap = f: list: lib.attrsets.mergeAttrsList (map f list);
  in mergeMap ({ arrowKey, homeKey, hyprDir, resize }:
    mergeMap (key: {
      "SUPER, ${key}" = mkBind "movefocus" hyprDir;
      "SUPER SHIFT, ${key}" = mkBind "swapwindow" hyprDir;
      "SUPER CTRL, ${key}" = repeating mkBind "resizeactive" (resize "10");
    }) [arrowKey homeKey]
  ) (
    lib.map (directionList:
      lib.listToAttrs ((lib.zipListsWith lib.nameValuePair)
      ["arrowKey" "homeKey" "hyprDir" "resize"] directionList)
    ) [
      ["left"  "h" "l" (amount: "-${amount} 0")]
      ["down"  "j" "d" (amount: "0 ${amount}")]
      ["up"    "k" "u" (amount: "0 -${amount}")]
      ["right" "l" "r" (amount: "${amount} 0")]
    ]
  ))

  (lib.attrsets.mergeAttrsList (builtins.genList (
    x:
    let
      workspacenum = builtins.toString (x + 1);
      key = builtins.toString (if x == 9 then 0 else x + 1);
    in {
      # Switch workspaces with mainMod + [0-9]
      "SUPER, ${key}" = mkBind "workspace" workspacenum;
      # Move active window to a workspace with mainMod + SHIFT + [0-9]
      "SUPER SHIFT, ${key}" = mkBind "movetoworkspace" workspacenum;
    }
  ) 10))
  ];
  wayland.windowManager.hyprland = {
    settings = {
      binds = {
        allow_workspace_cycles = true;
      };
    };
  };
}
