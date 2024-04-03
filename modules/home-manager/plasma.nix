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
      # extra cursor stuff
      "kcminputrc"."Mouse"."cursorTheme".value = "Win10OS-cursors";

      # fonts
      "kdeglobals"."General"."fixed".value = "Monospace,10,-1,5,50,0,0,0,0,0";
      "kdeglobals"."General"."font".value = "Sans Serif,10,-1,5,50,0,0,0,0,0";
      "kdeglobals"."General"."menuFont".value = "Sans Serif,10,-1,5,50,0,0,0,0,0";
      "kdeglobals"."General"."smallestReadableFont".value = "Sans Serif,8,-1,5,50,0,0,0,0,0";
      "kdeglobals"."General"."toolBarFont".value = "Sans Serif,10,-1,5,50,0,0,0,0,0";
      "kdeglobals"."WM"."activeFont".value = "Sans Serif,10,-1,5,50,0,0,0,0,0";

      # night light
      "kwinrc"."NightColor"."Active".value = true;
      "kwinrc"."NightColor"."Mode".value = "Constant";

      # faster animations
      "kdeglobals"."KDE"."AnimationDurationFactor".value = 0.25;

      # alt-tab menu
      "kwinrc"."TabBox"."LayoutName".value = "thumbnail_grid";

      # change window opacity on scroll (titlebar or Meta + anywhere else)
      "kwinrc"."MouseBindings"."CommandAllWheel".value = "Change Opacity";
      "kwinrc"."MouseBindings"."CommandTitlebarWheel".value = "Change Opacity";

      # don't show logout screen
      "ksmserverrc"."General"."confirmLogout".value = false;

      # window rules
      "kwinrulesrc"."General"."count".value = 1;
      "kwinrulesrc"."General"."rules".value = "871c18ba-a0ff-464f-8698-351caad3e3d8";
      # gvim maximising
      "kwinrulesrc"."871c18ba-a0ff-464f-8698-351caad3e3d8"."Description".value = "gvim maximised";
      "kwinrulesrc"."871c18ba-a0ff-464f-8698-351caad3e3d8"."wmclass".value = "gvim";
      "kwinrulesrc"."871c18ba-a0ff-464f-8698-351caad3e3d8"."wmclassmatch".value = 1;
      "kwinrulesrc"."871c18ba-a0ff-464f-8698-351caad3e3d8"."strictgeometryrule".value = 2;
      "kwinrulesrc"."871c18ba-a0ff-464f-8698-351caad3e3d8"."types".value = 1;
    };
  };
}
