{ lib, pkgs, ... }:

{
  wayland.windowManager.hyprland = {
    settings =
    let
      pactlBin = lib.getExe' pkgs.pulseaudio "pactl";
      jqBin = lib.getExe pkgs.jq;
      selectAudio = pkgs.pkgs.writeShellScriptBin "selectAudio" ''
        if [ "$ROFI_RETV" == "0" ]; then
          echo -e "\0data\x1ftype"
          echo "sinks"
          echo "sources"
          echo "sources (extra)"
          exit 0
        fi

        case "$ROFI_DATA" in
          "type")
            case "$1" in
              "sinks")
                type="sink"
              ;;
              "sources")
                type="source"
                filterMonitors=1
              ;;
              "sources (extra)")
                type="source"
              ;;
              *)
                exit 0
              ;;
            esac
            echo -e "\0data\x1f$type"
            defaultDevice="$(${pactlBin} get-default-''${type})"
            ${pactlBin} --format json list ''${type}s | ${jqBin} --raw-output '
              '"''${filterMonitors+map(select(.monitor_source == \"\")) |}"'
              map(
                if .name == "'"$defaultDevice"'" then "* " else "" end +
                .description + "\u0000info\u001f" + .name
              ) |
              .[]
            '
          ;;
          "sink" | "source")
            ${pactlBin} set-default-$ROFI_DATA "$ROFI_INFO"
          ;;
        esac
      '';
    in {
      bind = [
        "SUPER, A, exec, rofi -show selectAudio -modes \"selectAudio:${lib.getExe selectAudio}\" "
      ];
    };
  };
}
