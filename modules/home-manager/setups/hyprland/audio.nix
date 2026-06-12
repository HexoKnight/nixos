{
  lib,
  pkgs,
  config,
  ...
}:

{
  wayland.windowManager.hyprland = {
    binds =
      let
        selectAudio = pkgs.local.writeNushellApplication {
          name = "selectAudio";
          text = lib.readFile ./selectAudio.nu;
          isModule = true;
          runtimeInputs = [
            pkgs.pulseaudio
            config.programs.tofi.package
          ];
        };
      in
      {
        "SUPER + A" = config.lib.hypr.binds.mkExec (lib.getExe selectAudio);
      };
  };
}
