{
  lib,
  config,
  ...
}:

let
  toLua = lib.generators.toLua { };

  touchpad-name = config.home-inputs.config.disable-touchpad;
  key = "XF86TouchpadToggle";
  send = msg: "notify-send --urgency normal --expire-time 3000 ${lib.escapeShellArg msg}";
in
{
  config = lib.mkIf (touchpad-name != null) {
    wayland.windowManager.hyprland = {
      extraConfig = ''
        local touchpad_enabled = false
        hl.device({
          name = ${toLua touchpad-name},
          enabled = touchpad_enabled,
        })

        hl.bind(${toLua key}, function()
          touchpad_enabled = not touchpad_enabled
          hl.device({
            name = ${toLua touchpad-name},
            enabled = touchpad_enabled,
          })

          if touchpad_enabled then
            hl.exec_cmd(${toLua (send "Enabled Touchpad")})
          else
            hl.exec_cmd(${toLua (send "Disabled Touchpad")})
          end
        end)
      '';
    };
  };
}
