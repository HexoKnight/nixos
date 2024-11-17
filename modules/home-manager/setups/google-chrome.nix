{ lib, pkgs, config, ... }:

let
  cfg = config.setups.google-chrome;
in
{
  options.setups.google-chrome = {
    enable = lib.mkEnableOption "google chrome";
    xwayland = lib.mkOption {
      description = "Whether to force xwayland.";
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    persist-home = {
      directories = [
        ".config/google-chrome"
        # cache for logged in accounts and stuff
        ".cache/google-chrome"
      ];
    };

    home.packages = lib.singleton (pkgs.google-chrome.override {
      commandLineArgs = [
        "--incognito"
        "--enable-blink-features=MiddleClickAutoscroll"

        # dunno if webgpu is really necessary
        "--enable-unsafe-webgpu"

        # can't get hardware acceleration to work (on nvidia) :/
        # https://wiki.archlinux.org/title/Chromium#Hardware_video_acceleration
        # "--enable-features=VaapiVideoDecodeLinuxGL"
        # "--ignore-gpu-blocklist"
        # "--enable-zero-copy"

      ] ++ lib.optionals cfg.xwayland [
        # so forcing xwayland
        "--ozone-platform=x11"
      ];
    });
  };
}
