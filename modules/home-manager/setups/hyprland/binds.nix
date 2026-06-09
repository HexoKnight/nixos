{
  lib,
  pkgs,
  config,
  ...
}:

{
  config = {
    wayland.windowManager.hyprland = {
      binds =
        let
          inherit (config.lib.hypr.binds)
            mkBind
            mkNoArgBind
            mkExec
            mkMouseBind

            withFlag
            repeating
            ;
        in
        lib.mkMerge [
          {
            "SUPER + grave" = [
              (mkExec "hyprctl keyword input:follow_mouse 1")
              (withFlag "release" mkExec "hyprctl keyword input:follow_mouse 2")
            ];
            "SUPER + Q" = mkNoArgBind "window.close";
            "SUPER + T" = mkExec config.home.sessionVariables.TERMINAL;
            "SUPER + B" = mkExec "x-www-browser";
            "SUPER + CTRL + ALT + delete" = mkNoArgBind "exit";
            "SUPER + E" = mkExec "lf";
            "SUPER + R" = mkExec "rofi -show run";
            "SUPER + SHIFT + R" = mkExec "rofi -show drun";

            "SUPER + P" = mkNoArgBind "window.pseudo";
            "SUPER + S" = mkBind "layout" "togglesplit";

            "SUPER + V" = mkBind "window.float" { action = "toggle"; };
            "SUPER + F" = mkBind "window.fullscreen" {
              mode = "fullscreen";
              action = "toggle";
            };
            "SUPER + SHIFT + F" = mkBind "window.fullscreen" {
              mode = "maximized";
              action = "toggle";
            };
            "SUPER + ALT + F" = mkBind "window.fullscreen_state" {
              internal = 2; # fullscreen
              client = 0; # but don't tell application
              action = "toggle";
            };
            "SUPER + CTRL + F" = mkBind "window.fullscreen_state" {
              internal = 0; # not actually fullscreen
              client = 2; # but tell application it is
              action = "toggle";
            };

            "SUPER + SHIFT + S" = mkExec ''${lib.getExe pkgs.grim} -g "$(${lib.getExe pkgs.slurp})"'';

            "SUPER + M" = mkBind "focus" { monitor = "+1"; };
            "SUPER + SHIFT + M".rawLua =
              { }:
              lib.mkLuaInline ''
                hl.dispatch(hl.dsp.workspace.move({
                  workspace = hl.get_active_workspace().id,
                  monitor = "+1",
                }))
              '';

            # Example special workspace (scratchpad)
            # "SUPER + S" = mkBind "workspace.toggle_special" "magic";
            # "SUPER + SHIFT + S" = mkBind "window.move" { workspace = "special:magic"; };

            # Scroll through existing workspaces with mainMod + scroll
            "SUPER + mouse_down" = mkBind "focus" { workspace = "e+1"; };
            "SUPER + mouse_up" = mkBind "focus" { workspace = "e-1"; };

            # Move/resize windows with mainMod + LMB/RMB and dragging
            "SUPER + mouse:272" = mkMouseBind "window.drag";
            "SUPER + mouse:273" = mkMouseBind "window.resize";

            # ALT-tab / SUPER-tab
            "SUPER + tab" = mkBind "focus" { workspace = "previous"; };
            "ALT + tab" = mkBind "focus" { workspace = "previous"; };
          }

          (
            let
              brightnessctl = lib.getExe pkgs.brightnessctl;
            in
            {
              "XF86KbdBrightnessUp" = mkExec "${brightnessctl} -d *::kbd_backlight s +1";
              "XF86KbdBrightnessDown" = mkExec "${brightnessctl} -d *::kbd_backlight s 1-";
            }
          )

          (
            let
              swayosd-client = lib.getExe' config.services.swayosd.package "swayosd-client";
            in
            {
              "XF86MonBrightnessUp" = repeating mkExec "${swayosd-client} --brightness +5";
              "XF86MonBrightnessDown" = repeating mkExec "${swayosd-client} --brightness -5";

              "XF86AudioRaiseVolume" = repeating mkExec "${swayosd-client} --output-volume +5";
              "XF86AudioLowerVolume" = repeating mkExec "${swayosd-client} --output-volume -5";
              "XF86AudioMute" = mkExec "${swayosd-client} --output-volume mute-toggle";

              "SHIFT + XF86AudioRaiseVolume" = repeating mkExec "${swayosd-client} --input-volume +5";
              "SHIFT + XF86AudioLowerVolume" = repeating mkExec "${swayosd-client} --input-volume -5";
              "SHIFT + XF86AudioMute" = mkExec "${swayosd-client} --input-volume mute-toggle";
            }
          )

          (
            let
              mergeMap = f: list: lib.attrsets.mergeAttrsList (map f list);
            in
            mergeMap
              (
                {
                  direction,
                  homeKey,
                  resize,
                }:
                mergeMap
                  (key: {
                    "SUPER + ${key}" = mkBind "focus" { inherit direction; };
                    "SUPER + SHIFT + ${key}" = mkBind "window.swap" { inherit direction; };
                    "SUPER + CTRL + ${key}" = repeating mkBind "window.resize" (resize 10 // { relative = true; });
                  })
                  [
                    direction # arrow key
                    homeKey
                  ]
              )
              [
                {
                  direction = "left";
                  homeKey = "h";
                  resize = amount: {
                    x = -amount;
                    y = 0;
                  };
                }
                {
                  direction = "down";
                  homeKey = "j";
                  resize = amount: {
                    x = 0;
                    y = amount;
                  };
                }
                {
                  direction = "up";
                  homeKey = "k";
                  resize = amount: {
                    x = 0;
                    y = -amount;
                  };
                }
                {
                  direction = "right";
                  homeKey = "l";
                  resize = amount: {
                    x = amount;
                    y = 0;
                  };
                }
              ]

          )

          (lib.attrsets.mergeAttrsList (
            builtins.genList (
              x:
              let
                workspace = builtins.toString (x + 1);
                key = builtins.toString (if x == 9 then 0 else x + 1);
              in
              {
                # Switch workspaces with mainMod + [0-9]
                "SUPER + ${key}" = mkBind "focus" { inherit workspace; };
                # Move active window to a workspace with mainMod + SHIFT + [0-9]
                "SUPER + SHIFT + ${key}" = mkBind "window.move" { inherit workspace; };
              }
            ) 10
          ))
        ];

      settings.config = {
        binds = {
          allow_workspace_cycles = true;
        };
      };
    };
  };
}
