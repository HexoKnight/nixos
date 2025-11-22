{ lib, pkgs, ... }:

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
    moveToWorkspace = name:
      ''hyprctl dispatch movetoworkspace name:${name}'';
    moveToWorkspaceSilent = name:
      ''hyprctl dispatch movetoworkspacesilent name:${name}'';
    gotoWorkspace = name:
      ''hyprctl dispatch workspace name:${name}'';

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

    # SPECIAL WORKSPACES
    getSpecialWorkspaces = ''
      hyprctl workspaces -j |
      ${jqBin} --raw-output '
        .[].name |
        select(startswith("special")) |
        if . == "special" then "" else ltrimstr("special:") end
      '
    '';
    # non-zero exit code when there is no special workspace activated
    # empty string when the anonymous special workspace is activated
    getCurrentSpecialWorkspace = ''
      hyprctl monitors -j |
      ${jqBin} --raw-output '
        .[] |
        select(.focused==true).specialWorkspace.name |
        if . == "" then halt_error end |
        if . == "special" then "" else ltrimstr("special:") end
      '
    '';
    moveToSpecialWorkspace = name:
      ''hyprctl dispatch movetoworkspace special:${name}'';
    moveToSpecialWorkspaceSilent = name:
      ''hyprctl dispatch movetoworkspacesilent special:${name}'';
    toggleSpecialWorkspace = name:
      ''hyprctl dispatch togglespecialworkspace ${name}'';
    closeCurrentSpecialWorkspace = ''
      currentSpecialWorkspace="$(${getCurrentSpecialWorkspace})" &&
      ${toggleSpecialWorkspace "\${currentSpecialWorkspace}"}
    '';

    # EXTRA SPECIAL WORKSPACES
    getExtraSpecialWorkspaces = ''
      hyprctl workspaces -j |
      ${jqBin} --raw-output '
        .[].name |
        select(startswith("special:${extraPrefix}")) |
        ltrimstr("special:${extraPrefix}")
      '
    '';
    # non-zero exit code when there is no extra special workspace activated
    getCurrentExtraSpecialWorkspace = ''
      hyprctl monitors -j |
      ${jqBin} --raw-output '
        .[] |
        select(.focused==true).specialWorkspace.name |
        if startswith("special:${extraPrefix}") then
          ltrimstr("special:${extraPrefix}")
        else
          "" | halt_error
        end
      '
    '';
    moveToExtraSpecialWorkspace = name: moveToSpecialWorkspace (getExtraName name);
    moveToExtraSpecialWorkspaceSilent = name: moveToSpecialWorkspaceSilent (getExtraName name);
    toggleExtraSpecialWorkspace = name: toggleSpecialWorkspace (getExtraName name);
  };
in
{
  config.lib.hyprland = {
    inherit workspaces;
  };

  config.wayland.windowManager.hyprland = {
    settings =
    let
      w = workspaces;

      freceBin = lib.getExe pkgs.frece;
      # actOnWorkspace must return a non-zero exit code if the db
      # should not be updated (eg. it was a noop or it was invalid)
      createWorkspaceAction = binName: getWorkspaces: actOnWorkspace:
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
      gotoExtraWorkspaceBin = createWorkspaceAction
        "gotoExtraWorkspace" w.getExtraWorkspaces (ifNotEqualTo w.getCurrentExtraWorkspace w.gotoExtraWorkspace);
      moveToExtraWorkspaceBin = createWorkspaceAction
        "moveToExtraWorkspace" w.getExtraWorkspaces w.moveToExtraWorkspace;
    in {
      bind = [
        "SUPER, D, exec, ${gotoExtraWorkspaceBin}"
        "SUPER SHIFT, D, exec, ${moveToExtraWorkspaceBin}"
      ];
    };
  };
}
