{ lib, pkgs, config, ... }:

let
  touchpad-name = config.home-inputs.config.disable-touchpad;

  touchpad-enabled-var = "$TOUCHPAD_ENABLED";
  toggle-touchpad = lib.getExe (pkgs.writeShellScriptBin "toggle-touchpad" ''
    STATUS_FILE=$XDG_RUNTIME_DIR/touchpad-status

    send_notification() {
      notify-send --urgency normal --expire-time 3000 "$@"
    }

    enable() {
      printf "enabled" >"$STATUS_FILE"
      send_notification "Enabling Touchpad"
      hyprctl keyword '${touchpad-enabled-var}' "true" -r
    }

    disable() {
      printf "disabled" >"$STATUS_FILE"
      send_notification "Disabling Touchpad"
      hyprctl keyword '${touchpad-enabled-var}' "false" -r
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
        enabled = ${touchpad-enabled-var}
      }
    '';
    settings = {
      ${touchpad-enabled-var} = false;

      bind = [
        ", XF86TouchpadToggle, exec, ${toggle-touchpad}"
      ];
    };
  };
}
