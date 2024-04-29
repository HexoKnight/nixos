{ config, system-config, lib, pkgs, inputs, ... }:

with lib; {
  home.packages = with pkgs; [
    kitty

    rofi-wayland

    mako
    libnotify
  ];
  # Optional, hint electron apps to use wayland:
  # environment.sessionVariables.NIXOS_OZONE_WL = "1";

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome.gnome-themes-extra;
    };
    gtk3.extraConfig = {
      Setting = ''
        gtk-application-prefer-dark-theme=1
      '';
    };
    gtk4.extraConfig = {
      Setting = ''
        gtk-application-prefer-dark-theme=1
      '';
    };
  };

  programs.waybar = {
    enable = true;
    systemd.enable = true;
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = system-config.programs.hyprland.finalPackage;
    plugins = [
      inputs.hycov.packages.${pkgs.system}.hycov
    ];
    settings = with pkgs; {
      monitor = ",preferred,auto,1";

      env = [
        # idk if this is necessary
        # "XCURSOR_SIZE,24"
      ];

      general = {
        gaps_in = 0;
        gaps_out = 0;
        border_size = 1;
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";

        layout = "dwindle";

        # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
        allow_tearing = false;
      };

      input = {
        kb_layout = system-config.services.xserver.layout;
        kb_variant = system-config.services.xserver.xkbVariant;

        follow_mouse = 1;
        mouse_refocus = false;

        touchpad = {
          natural_scroll = true;
        };
        sensitivity = 0; # -1.0 - 1.0, 0 means no modification.
      };

      decoration = {
        rounding = 0;

        blur = {
          enabled = false;
          size = 3;
          passes = 1;
        };

        drop_shadow = true;
        shadow_range = 4;
        shadow_render_power = 3;
        "col.shadow" = "rgba(1a1a1aee)";
      };

      animations = {
        enabled = true;

        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";

        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };
      master = {
        new_is_master = true;
      };

      gestures = {
        workspace_swipe = false;
      };

      misc = {
        force_default_wallpaper = -1;
        disable_hyprland_logo = true;
      };

      binds = {
        allow_workspace_cycles = true;
      };

      "$mainMod" = "SUPER";
      bind = [
        # Example binds, see https://wiki.hyprland.org/Configuring/Binds/ for more
        "$mainMod, Q, exec, $TERMINAL"
        "$mainMod, C, killactive, "
        "$mainMod, M, exit, "
        "$mainMod, E, exec, lf"
        "$mainMod, V, togglefloating, "
        "$mainMod, R, exec, rofi -show run"
        "$mainMod SHIFT, R, exec, rofi -show drun"

        # Move focus with mainMod + arrow keys
        "$mainMod, H, movefocus, l"
        "$mainMod, J, movefocus, d"
        "$mainMod, K, movefocus, u"
        "$mainMod, L, movefocus, r"

        # Example special workspace (scratchpad)
        "$mainMod, S, togglespecialworkspace, magic"
        "$mainMod SHIFT, S, movetoworkspace, special:magic"

        # Scroll through existing workspaces with mainMod + scroll
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"

        # ALT-tab / SUPER-tab
        "$mainMod, tab, workspace, previous"
        "ALT, tab, workspace, previous"
      ]
      ++ (let
        swayosd = "${pkgs.swayosd}/bin/swayosd";
      in [
        # volume
        ", XF86AudioRaiseVolume, exec, ${swayosd} --output-volume raise"
        ", XF86AudioLowerVolume, exec, ${swayosd} --output-volume lower"
        ", XF86AudioMute,        exec, ${swayosd} --output-volume mute-toggle"
      ])
      ++ builtins.concatLists (builtins.genList (
        x:
        let
          workspacenum = builtins.toString (x + 1);
          key = builtins.toString (if x == 9 then 0 else x + 1);
        in [
          # Switch workspaces with mainMod + [0-9]
          "$mainMod, ${key}, workspace, ${workspacenum}"
          # Move active window to a workspace with mainMod + SHIFT + [0-9]
          "$mainMod SHIFT, ${key}, movetoworkspace, ${workspacenum}"
        ]
      ) 10);

      bindm = [
        # Move/resize windows with mainMod + LMB/RMB and dragging
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];
    };
  };
}
