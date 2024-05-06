{ config, system-config, lib, pkgs, inputs, ... }:

let
  workspaces = rec {
    # NORMAL WORKSPACES
    getNormalWorkspaces = ''
      hyprctl workspaces -j |
      ${pkgs.jq}/bin/jq --raw-output '
        .[].name |
        select(startswith("special") | not)
      '
    '';
    getCurrentNormalWorkspace = ''
      hyprctl monitors -j |
      ${pkgs.jq}/bin/jq --raw-output '
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
      ${pkgs.jq}/bin/jq --raw-output '
        .[].name |
        select(startswith("${extraPrefix}")) |
        ltrimstr("${extraPrefix}")
      '
    '';
    # non-zero exit code when there is no extra workspace activated
    getCurrentExtraWorkspace = ''
      hyprctl monitors -j |
      ${pkgs.jq}/bin/jq --raw-output '
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
      ${pkgs.jq}/bin/jq --raw-output '
        .[].name |
        select(startswith("special")) |
        if . == "special" then "" else ltrimstr("special:") end
      '
    '';
    # non-zero exit code when there is no special workspace activated
    # empty string when the anonymous special workspace is activated
    getCurrentSpecialWorkspace = ''
      hyprctl monitors -j |
      ${pkgs.jq}/bin/jq --raw-output '
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
      ${pkgs.jq}/bin/jq --raw-output '
        .[].name |
        select(startswith("special:${extraPrefix}")) |
        ltrimstr("special:${extraPrefix}")
      '
    '';
    # non-zero exit code when there is no extra special workspace activated
    getCurrentExtraSpecialWorkspace = ''
      hyprctl monitors -j |
      ${pkgs.jq}/bin/jq --raw-output '
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
  options.hyprland-workspaces = with lib; mkOption {
    type = types.attrs;
    visible = false;
    readOnly = true;
    default = workspaces;
  };

  config.wayland.windowManager.hyprland = {
    settings = with pkgs;
    with workspaces;
    let
      frece = pkgs.frece + "/bin/frece";
      # actOnWorkspace must return a non-zero exit code if the db
      # should not be updated (eg. it was a noop or it was invalid)
      createWorkspaceAction = binName: getWorkspaces: actOnWorkspace:
        (pkgs.pkgs.writeShellScriptBin binName (let
            updateFrece =  ''
              extraWorkspaces="$(${getWorkspaces})"
              ${frece} update "$DB_FILE" <(echo "$extraWorkspaces")
            '';
          in ''
          DB_FILE="''${XDG_STATE_HOME:-$HOME/.local/state}/${binName}.db"

          ${updateFrece}
          options="$(${frece} print "$DB_FILE")"
          workspace=$(if [ -n "$options" ]; then echo "$options"; fi | rofi -dmenu)
          if [ -n "$workspace" ] && [ "$workspace" != "$(${getCurrentExtraWorkspace})" ]; then
            ( ${actOnWorkspace "\${workspace}"} ) && {
              ${updateFrece}
              ${frece} increment "$DB_FILE" "$workspace"
            }
          fi
        '')) + "/bin/" + binName;
      # TODO: finish up
      ifNotCurrent = getCurrent: workspace: ''
      '';
      gotoExtraWorkspaceBin = createWorkspaceAction
        "gotoExtraWorkspace" getExtraWorkspaces gotoExtraWorkspace;
      moveToExtraWorkspaceBin = createWorkspaceAction
        "moveToExtraWorkspace" getExtraWorkspaces moveToExtraWorkspace;
      # closeCurrentSpecialWorkspaceBin = (pkgs.pkgs.writeShellScriptBin "closeCurrentSpecialWorkspace" ''
      #   ${closeCurrentSpecialWorkspace}
      # '') + "/bin/closeCurrentSpecialWorkspace";
    in {
      bind = [
        "SUPER, D, exec, ${gotoExtraWorkspaceBin}"
        "SUPER SHIFT, D, exec, ${moveToExtraWorkspaceBin}"
        # "SUPER SHIFT, D, exec, ${closeCurrentSpecialWorkspaceBin}"
      ];
    };
  };
}
