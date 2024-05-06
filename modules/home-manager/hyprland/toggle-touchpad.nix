touchpad-name:

{ config, system-config, lib, pkgs, inputs, ... }:

let
  touchpad-enabled = "$TOUCHPAD_ENABLED";
  toggle-touchpad = (pkgs.pkgs.writeShellScriptBin "toggle-touchpad" ''
    export STATUS_FILE="$XDG_RUNTIME_DIR/keyboard.status"

    enable() {
      printf "true" >"$STATUS_FILE"
      notify-send -u normal "Enabling Touchpad"
      hyprctl keyword '${touchpad-enabled}' "true" -r
    }

    disable() {
      printf "false" >"$STATUS_FILE"
      notify-send -u normal "Disabling Touchpad"
      hyprctl keyword '${touchpad-enabled}' "false" -r
    }

    if ! [ -f "$STATUS_FILE" ]; then
      enable
    else
      if [ $(cat "$STATUS_FILE") = "true" ]; then
        disable
      elif [ $(cat "$STATUS_FILE") = "false" ]; then
        enable
      fi
    fi
  '') + "/bin/toggle-touchpad";
in
{
  wayland.windowManager.hyprland = {
    extraConfig = ''
      # later hyprland versions
      # device {
      #   name = ${touchpad-name}
      device:${touchpad-name} {
        enabled = ${touchpad-enabled}
      }
    '';
    settings = {
      ${touchpad-enabled} = false;

      bind = [
        ", XF86TouchpadToggle, exec, ${toggle-touchpad}"
      ];
    };
  };
}
