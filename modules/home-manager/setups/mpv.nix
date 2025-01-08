{ lib, pkgs, config, ... }:

let
  cfg = config.setups.mpv;
in
{
  options.setups.mpv = {
    enable = lib.mkEnableOption "mpv";
  };

  config = lib.mkIf cfg.enable {
    persist-home = {
      directories = [
        ".config/mpv"
        ".local/state/mpv"
      ];
    };

    programs.mpv = {
      enable = true;
      scripts = with pkgs.mpvScripts; [
        # alternate improved ui
        uosc
        # optionally used by uosc for thumbnails
        thumbfast

        # press ?
        mpv-cheatsheet

        # fixes https://github.com/hoyon/mpv-mpris/issues/98
        (mpris.overrideAttrs (oldAttrs: {
          version = "unstable-2023-26-10";

          src = pkgs.fetchFromGitHub {
            owner = "hoyon";
            repo = "mpv-mpris";
            rev = "16fee38988bb0f4a0865b6e8c3b332df2d6d8f14";
            hash = "sha256-q0QhVhXOPFva1CVedox5X/dmUtR4aTaCK4BIBL+pkhY=";
          };
        }))
      ];

      bindings = {
        tab = "script-binding uosc/toggle-ui";
        ":" = "script-binding uosc/menu";
        mouse_move = "script-binding uosc/flash-ui";
      };

      scriptOpts = {
        uosc = {
          top_bar = "always";
          top_bar_controls = false;
          autohide = true;
        };
      };

      config = {
        save-position-on-quit = true;
        alang = "en-GB";
        slang = "en-GB";
        vlang = "en-GB";
      };
    };
  };
}
