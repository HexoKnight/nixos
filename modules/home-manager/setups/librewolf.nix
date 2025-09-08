{ lib, pkgs, config, ... }:

let
  cfg = config.setups.librewolf;
in
{
  options.setups.librewolf = {
    enable = lib.mkEnableOption "LibreWolf";
  };

  config = lib.mkIf cfg.enable {
    persist-home = {
      directories = [
        ".librewolf"
      ];
    };

    programs.librewolf = {
      enable = true;

      package = pkgs.librewolf.overrideAttrs (oldAttrs: {
        makeWrapperArgs = oldAttrs.makeWrapperArgs ++ [
          # default to opening a private window
          "--add-flags" "--private-window"
        ];
      });

      languagePacks = [ "en-GB" ];

      settings = {
        "webgl.disabled" = false;
        "privacy.resistFingerprinting" = false;
        "privacy.clearOnShutdown.history" = false;
        "privacy.clearOnShutdown.cookies" = false;

        "intl.regional_prefs.use_os_locales" = true;

        "middlemouse.paste" = false;
        "general.autoScroll" = true;
        "media.autoplay.blocking_policy" = 2;

        # enable userChrome.css
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
      };

      policies = {
        RequestedLocales = "en-GB,en";

        DefaultDownloadDirectory = "/tmp";
        PromptForDownloadLocation = true;

        ExtensionSettings = let
          moz = short: "https://addons.mozilla.org/firefox/downloads/latest/${short}/latest.xpi";
        in {
          "uBlock0@raymondhill.net" = {
            install_url = moz "ublock-origin";
            installation_mode = "normal_installed";
            private_browsing = true;
          };

          "CanvasBlocker@kkapsner.de" = {
            install_url = moz "canvasblocker";
            installation_mode = "normal_installed";
            private_browsing = true;
          };

          # until this patch makes it so stable:
          # https://github.com/nix-community/home-manager/commit/153e680c4263fbd8fa416ef5b8ef13397e02fd2f
          "langpack-en-GB@firefox.mozilla.org".install_url =
            let
              release = builtins.head (lib.splitString "-" config.programs.librewolf.package.version);
            in
            lib.mkForce "https://releases.mozilla.org/pub/firefox/releases/${release}/linux-x86_64/xpi/en-GB.xpi";
        };
      };

      profiles.default = {
        isDefault = true;

        # to fix issue:
        # https://github.com/hyprwm/Hyprland/issues/10515
        # workaround from here:
        # https://github.com/hyprwm/Hyprland/discussions/10355#discussioncomment-13181787
        userChrome = ''
          :root:not([chromehidden~="toolbar"]){
            min-width: 20px !important;
          }
        '';
      };
    };
  };
}
