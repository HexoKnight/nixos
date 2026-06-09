{
  lib,
  pkgs,
  config,
  ...
}:

let
  jqBin = lib.getExe pkgs.jq;

  workspaces = rec {
    # NORMAL WORKSPACES
    getNormalWorkspaces = ''
      hyprctl workspaces -j |
      ${jqBin} --raw-output '
        .[].name |
        select(startswith("special") | not)
      '
    '';
    getCurrentNormalWorkspace = ''
      hyprctl monitors -j |
      ${jqBin} --raw-output '
        .[] |
        select(.focused==true).activeWorkspace.name
      '
    '';
    moveToWorkspace = name: ''hyprctl dispatch "hl.dsp.window.move({ workspace = [[name:${name}]] })"'';
    moveToWorkspaceSilent =
      name: ''hyprctl dispatch "hl.dsp.window.move({ workspace = [[name:${name}]], follow = false })"'';
    gotoWorkspace = name: ''hyprctl dispatch "hl.dsp.focus({ workspace = [[name:${name}]] })"'';

    # EXTRA NORMAL WORKSPACES
    extraPrefix = "__";
    getExtraName = name: extraPrefix + name;
    getExtraWorkspaces = ''
      hyprctl workspaces -j |
      ${jqBin} --raw-output '
        .[].name |
        select(startswith("${extraPrefix}")) |
        ltrimstr("${extraPrefix}")
      '
    '';
    # non-zero exit code when there is no extra workspace activated
    getCurrentExtraWorkspace = ''
      hyprctl monitors -j |
      ${jqBin} --raw-output '
        .[] |
        select(.focused==true).activeWorkspace.name |
        if startswith("${extraPrefix}") then
          ltrimstr("${extraPrefix}")
        else
          "" | halt_error
        end
      '
    '';
    moveToExtraWorkspace = name: moveToWorkspace (getExtraName name);
    moveToExtraWorkspaceSilent = name: moveToWorkspaceSilent (getExtraName name);
    gotoExtraWorkspace = name: gotoWorkspace (getExtraName name);
  };
in
{
  config.wayland.windowManager.hyprland = {
    binds =
      let
        w = workspaces;

        freceBin = lib.getExe pkgs.frece;
        # actOnWorkspace must return a non-zero exit code if the db
        # should not be updated (eg. it was a noop or it was invalid)
        createWorkspaceAction =
          binName: getWorkspaces: actOnWorkspace:
          lib.scripts.mkScript pkgs binName ''
            DB_FILE="''${XDG_STATE_HOME:-$HOME/.local/state}/${binName}.db"

            workspaces="$(
              ${getWorkspaces}
            )"
            ${freceBin} update "$DB_FILE" <(echo "$workspaces")
            options="$(${freceBin} print "$DB_FILE" | grep -Fx "$workspaces")"
            workspace=$(if [ -n "$options" ]; then echo "$options"; fi | rofi -dmenu)
            if [ -n "$workspace" ]; then
              {
                ${actOnWorkspace "\${workspace}"}
              } && {
                workspaces="$(
                  ${getWorkspaces}
                )"
                ${freceBin} update "$DB_FILE" <(echo "$workspaces")
                ${freceBin} increment "$DB_FILE" "$workspace"
              }
            fi
          '';
        ifNotEqualTo = getOther: actOnWorkspace: workspace: ''
          [ "${workspace}" != "$(${getOther})" ] &&
          ${actOnWorkspace workspace}
        '';
        gotoExtraWorkspaceBin = createWorkspaceAction "gotoExtraWorkspace" w.getExtraWorkspaces (
          ifNotEqualTo w.getCurrentExtraWorkspace w.gotoExtraWorkspace
        );
        moveToExtraWorkspaceBin =
          createWorkspaceAction "moveToExtraWorkspace" w.getExtraWorkspaces
            w.moveToExtraWorkspace;
      in
      {
        "SUPER + D" = config.lib.hypr.binds.mkExec gotoExtraWorkspaceBin;
        "SUPER + SHIFT + D" = config.lib.hypr.binds.mkExec moveToExtraWorkspaceBin;
      };
  };
}
