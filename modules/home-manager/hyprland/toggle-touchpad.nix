{ config, system-config, lib, pkgs, inputs, ... }:

let
  touchpad-name = config.home-inputs.disable-touchpad;

  touchpad-enabled = "$TOUCHPAD_ENABLED";
  toggle-touchpad = lib.getExe (pkgs.writeShellScriptBin "toggle-touchpad" ''
    export STATUS_FILE=$XDG_RUNTIME_DIR/touchpad-status

    enable() {
      printf "enabled" >"$STATUS_FILE"
      notify-send -u normal "Enabling Touchpad"
      hyprctl keyword '${touchpad-enabled}' "true" -r
    }

    disable() {
      printf "disabled" >"$STATUS_FILE"
      notify-send -u normal "Disabling Touchpad"
      hyprctl keyword '${touchpad-enabled}' "false" -r
    }

    if [ ! -f "$STATUS_FILE" ]; then
      enable
    else
      case "$(cat "$STATUS_FILE")" in
        enabled) disable ;;
        disabled) enable ;;
      esac
    fi
  '');
in
lib.mkIf (touchpad-name != null) {
  wayland.windowManager.hyprland = {
    extraConfig = ''
      device {
        name = ${touchpad-name}
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
