{
  lib,
  pkgs,
  config,
  ...
}:

let
  inherit (config.lib.hypr.binds)
    mkBind
    mkNoArgBind
    mkExec

    asCallback

    withFlag
    repeating
    ;

  toLua = lib.generators.toLua { };

  wlrctlBin = lib.getExe pkgs.wlrctl;
  wl-kbptrBin = lib.getExe pkgs.wl-kbptr;

  wl-kbptrConfig = lib.toFile "wl-kbptr-config" (
    lib.generators.toINI { } {
      general.home_row_keys = "asdfhjkliom";
      mode_floating.source = "detect";
    }
  );

  wl-kbptrCmd =
    config:
    "${wl-kbptrBin} ${
      lib.escapeShellArgs (
        [
          "-c"
          wl-kbptrConfig
        ]
        ++ lib.cli.toCommandLine (optionName: {
          option = "-o${optionName}";
          sep = "=";
          explicitBool = true;
        }) config
      )
    }";

  mkSubmapExec = submapDuring: submapAfter: cmd: {
    rawLua =
      let
        dispatchSubmapAfter = "hl.dsp.submap(${toLua submapAfter})";
      in
      lib.mkLuaInline ''
        function()
          hl.dispatch(hl.dsp.submap(${toLua submapDuring}))
          hl.dispatch(hl.dsp.exec_cmd(${toLua "${cmd} ; hyprctl dispatch ${lib.escapeShellArg dispatchSubmapAfter}"}))
        end
      '';
  };

  mouse-config = enabled: {
    cursor.hide_on_key_press = !enabled;
    misc.mouse_move_focuses_monitor = enabled;
  };

  moveCursor =
    vector:
    repeating asCallback mkExec
      "${wlrctlBin} pointer move ${
        lib.escapeShellArgs [
          vector.x
          vector.y
        ]
      }";
  # this doesn't update the cursor state (hover, etc.) consistently
  # repeating asCallback mkBind "cursor.move" {
  #   x = lib.mkLuaInline "hl.get_cursor_pos().x + ${toLua vector.x}";
  #   y = lib.mkLuaInline "hl.get_cursor_pos().y + ${toLua vector.y}";
  # };

  # wlrctl doesn't work here for some reason
  # scrollCursor =
  #   vector:
  #   repeating asCallback mkExec
  #     "${wlrctlBin} pointer scroll ${
  #       lib.escapeShellArgs [
  #         vector.x
  #         vector.y
  #       ]
  #     }";
in
{
  config = {
    wayland.windowManager.hyprland = {
      binds = {
        "SUPER + space".rawLua = lib.mkLuaInline ''
          function()
            hl.dispatch(hl.dsp.submap("mouse"))
            hl.config(${toLua (mouse-config true)})
          end
        '';

      };
      submapBinds.mouse = lib.mkMerge [
        {
          "i" = mkExec "${wlrctlBin} pointer click left";
          "o" = mkExec "${wlrctlBin} pointer click right";
          "m" = mkExec "${wlrctlBin} pointer click middle";
          "c" = asCallback mkBind "cursor.move" {
            x = lib.mkLuaInline "hl.get_active_monitor().x + hl.get_active_monitor().width / 2";
            y = lib.mkLuaInline "hl.get_active_monitor().y + hl.get_active_monitor().height / 2";
          };

          "f" = mkSubmapExec "reset" "mouse" (wl-kbptrCmd {
            modes = "floating";
          });
          "g" = mkSubmapExec "reset" "mouse" (wl-kbptrCmd {
            modes = "split";
          });

          # "CTRL + u" = scrollCursor {
          #   x = 0;
          #   y = -100;
          # };
          # "CTRL + d" = scrollCursor {
          #   x = 0;
          #   y = 100;
          # };

          "escape" = withFlag "ignore_mods" {
            rawLua = lib.mkLuaInline ''
              function()
                hl.dispatch(hl.dsp.submap("reset"))
                hl.config(${toLua (mouse-config false)})
              end
            '';
          };

          "catchall" = withFlag "ignore_mods" mkNoArgBind "no_op";
        }

        (
          let
            mergeMap = f: list: lib.attrsets.mergeAttrsList (map f list);
          in
          mergeMap
            (
              {
                direction,
                homeKey,
                vector,
              }:
              mergeMap
                (key: {
                  ${key} = moveCursor (vector 10);
                  "SHIFT + ${key}" = moveCursor (vector 100);
                  # "CTRL + ${key}" = scrollCursor (vector 10);
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
                vector = amount: {
                  x = -amount;
                  y = 0;
                };
              }
              {
                direction = "down";
                homeKey = "j";
                vector = amount: {
                  x = 0;
                  y = amount;
                };
              }
              {
                direction = "up";
                homeKey = "k";
                vector = amount: {
                  x = 0;
                  y = -amount;
                };
              }
              {
                direction = "right";
                homeKey = "l";
                vector = amount: {
                  x = amount;
                  y = 0;
                };
              }
            ]
        )
      ];
    };
  };
}
