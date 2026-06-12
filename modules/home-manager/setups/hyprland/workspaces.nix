{
  lib,
  pkgs,
  config,
  ...
}:

let
  selectExtraWorkspace = pkgs.local.writeNushellApplication {
    name = "selectAudio";
    text = lib.readFile ./selectExtraWorkspace.nu;
    isModule = true;
    runtimeInputs = [
      config.programs.tofi.package
    ];
  };
in
{
  config.wayland.windowManager.hyprland = {
    binds = {
      "SUPER + D" = config.lib.hypr.binds.mkExec "${lib.getExe selectExtraWorkspace} goto";
      "SUPER + SHIFT + D" = config.lib.hypr.binds.mkExec "${lib.getExe selectExtraWorkspace} move";
    };
  };
}
