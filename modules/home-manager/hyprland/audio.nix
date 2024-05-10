{ config, system-config, lib, pkgs, inputs, ... }:

{
  wayland.windowManager.hyprland = {
    settings = with pkgs;
    let
      pactl =  "${pkgs.pulseaudio}/bin/pactl";
      jq =  "${pkgs.jq}/bin/jq";
      selectAudio = extra: (pkgs.pkgs.writeShellScriptBin "selectAudio" (
      let
        selectSinkSource = isSink:
        let
          type = if isSink then "sink" else "source";
        in ''
          defaultDevice="$(${pactl} get-default-${type})"
          devices="$(${pactl} --format json list ${type}s | ${jq} --raw-output '
            ${if extra || isSink then "" else ''map(select(.monitor_source == "")) |''}
            map({
              name,
              description: (if .name == "'"$defaultDevice"'" then "* " else "" end + .description)
            })
          ')"
          deviceIndex="$(echo "$devices" | ${jq} --raw-output '.[].description' | rofi -dmenu -format i)"
          if [ -n "deviceIndex" ] && [ "deviceIndex" != "-1" ]; then
            deviceName="$(echo "$devices" | ${jq} --raw-output ".[$deviceIndex].name")"
            ${pactl} set-default-${type} "$deviceName"
          fi
        '';
      in ''
        type=$(echo -e "sinks\nsources" | rofi -dmenu)
        if [ "$type" == "sinks" ]; then
          ${selectSinkSource true}
        elif [ "$type" == "sources" ]; then
          ${selectSinkSource false}
        fi
      '')) + "/bin/selectAudio";
    in {
      bind = [
        "SUPER, A, exec, ${selectAudio false}"
        "SUPER SHIFT, A, exec, ${selectAudio true}"
      ];
    };
  };
}
