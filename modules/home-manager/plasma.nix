{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    inputs.plasma-manager.homeManagerModules.plasma-manager
  ];

  programs.plasma = {
    enable = true;
    workspace = {
      clickItemTo = "select";
      lookAndFeel = "org.kde.breezedark.desktop";
      theme = "breeze-dark";
      colorScheme = "BreezeDark";
      cursorTheme = "Win10OS-cursors";
    };
    configFile = {
      "kdeglobals"."General"."fixed".value = "Monospace,10,-1,5,50,0,0,0,0,0";
      "kdeglobals"."General"."font".value = "Sans Serif,10,-1,5,50,0,0,0,0,0";
      "kdeglobals"."General"."menuFont".value = "Sans Serif,10,-1,5,50,0,0,0,0,0";
      "kdeglobals"."General"."smallestReadableFont".value = "Sans Serif,8,-1,5,50,0,0,0,0,0";
      "kdeglobals"."General"."toolBarFont".value = "Sans Serif,10,-1,5,50,0,0,0,0,0";
      "kdeglobals"."WM"."activeFont".value = "Sans Serif,10,-1,5,50,0,0,0,0,0";
    };
  };
}
