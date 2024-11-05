{ lib, pkgs, inputs, config, config_name, ... }:

let
  inherit (lib) mkOption mkEnableOption;

  mkListIf = condition: value: [ (lib.mkIf condition value) ];

  mkBoolOption = msg: lib.mkOption {
    description = "Whether to ${msg}.";
    type = lib.types.bool;
    default = false;
  };

  cfg = config.setups;

  inherit (cfg.config) username hostname device;
in
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  options.setups = {
    config = {
      username = mkOption {
        description = "The username of the main user.";
        type = lib.types.str;
      };
      hostname = mkOption {
        description = "The hostname of the system.";
        type = lib.types.str;
      };
      device = mkOption {
        description = "Device to install nixos on.";
        type = inputs.disko.lib.optionTypes.absolute-pathname;
      };

      extraUserOptions = mkOption {
        description = "Extra options passed to users.users.<username>.";
        type = lib.types.attrs;
        default = {};
      };
    };

    minimal = mkEnableOption "the minimal setup" // { default = cfg.desktop; };

    sops = mkEnableOption "sops password management" // { default = cfg.minimal; };

    installBootloader = mkBoolOption "Whether to install grub." // { default = cfg.minimal; };

    impermanence = mkEnableOption "impermanence";

    desktop = mkBoolOption "Whether the system should have a desktop." // { default = cfg.personal-gaming; };

    special-capslock = mkEnableOption "special-capslock" // { default = cfg.desktop; };

    networking = mkEnableOption "networking" // { default = cfg.desktop; };
    printing = mkEnableOption "printing";
    adb = mkEnableOption "adb";

    ssh = mkEnableOption "ssh stuff" // { default = cfg.minimal; };

    personal-gaming = mkBoolOption "Whether the user/system should have personal/gaming stuff.";

    flatpak = mkEnableOption "flatpak stuff";
  };

  config = lib.mkMerge (
    mkListIf cfg.minimal {
      # allows 'normal' UNIX shebangs (eg. #!/bin/bash)
      services.envfs.enable = true;

      networking.hostName = hostname;

      # TODO: integrate??
      userhome-config.${username} = {
        cansudo = true;
        persistence = cfg.impermanence;
        inherit (cfg) personal-gaming;
        extraOptions = {
          isNormalUser = true;
        } // cfg.config.extraUserOptions;
      };

      environment.variables = {
        # TODO: improve
        NIXOS_BUILD_FLAKE = ''
          git+file:///home/${username}/.nixos
          github:HexoKnight/nixos
          git+ssh://git@github.com/HexoKnight/nixos
        '';
        NIXOS_BUILD_CONFIGURATION = config_name;
      };
      environment.etc = {
        nixos-current-system-source.source = inputs.self;
      };

      # This value determines the NixOS release from which the default
      # settings for stateful data, like file locations and database versions
      # on your system were taken. It‘s perfectly fine and recommended to leave
      # this value at the release version of the first install of this system.
      # Before changing this value read the documentation for this option
      # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
      system.stateVersion = "23.11"; # Did you read the comment?
    } ++
    mkListIf cfg.sops {
      sops = {
        defaultSopsFile = "${inputs.self}/secrets.json";
        defaultSopsFormat = "json";

        gnupg.sshKeyPaths = [];
        age.sshKeyPaths = [];
        age.keyFile = (if cfg.impermanence then "/persist" else "") + "/home/${username}/.config/sops/age/keys.txt";

        secrets.hashedPassword = {
          neededForUsers = true;
        };
      };

      users.users.${username}.hashedPasswordFile = config.sops.secrets.hashedPassword.path;
    } ++
    mkListIf cfg.installBootloader {
      boot.loader = {
        grub.enable = true;
        grub.useOSProber = true;
        grub.devices = [ device ];
        grub.efiSupport = true;
        efi.canTouchEfiVariables = true;

        grub.timestampFormat = "%F %H:%M";
        grub.default = "saved";
      };
    } ++
    mkListIf cfg.impermanence {
      persist = {
        enable = true;
        defaultSetup = {
          enable = true;
          inherit (cfg.config) device;
        };
        system = {
          directories = [
            "/var/lib/systemd/backlight"
            "/var/lib/systemd/timers"
          ];
          files = [
            "/etc/machine-id"
          ];
        };
      };
    } ++
    mkListIf cfg.desktop {
      # TODO: integrate
      host-config = {
        desktop = true;
      };

      services.xserver.enable = true;

      services.displayManager.sddm = {
        enable = true;
        wayland.enable = true;
        theme = "where_is_my_sddm_theme_qt5";
      };
      environment.systemPackages = [
        # TODO: hardcode into sddm conf
        (pkgs.local.where-is-my-sddm-theme-qt5.override {
          themeConfig.General = {
            background = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            backgroundFill = "#000000";
            backgroundFillMode = "none";
            blurRadius = 32;
            passwordCharacter = "∗"; # ● • >∗ ﹡ ＊ ✲
            passwordInputWidth = 1.0;
            passwordCursorColor = "#ffffff";
            passwordInputCursorVisible = false;
            # sessionsFontSize = 24;
            # usersFontSize = 24;
            showUserRealNameByDefault = false;
          };
        })
      ];

      programs.hyprland = {
        enable = true;
      };

      sound.enable = true;
      # TODO: disable this options
      hardware.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };

      fonts.fontconfig = {
        enable = true;
        defaultFonts = {
          monospace = ["RobotoMono Nerd Font Mono"];
          sansSerif = ["Roboto"];
          serif = ["Roboto"];
        };
      };
      fonts.packages = with pkgs; [
        roboto
        (nerdfonts.override { fonts = [ "RobotoMono" ]; })
      ];
    } ++
    mkListIf cfg.special-capslock {
      # TODO: improve
      environment.etc."dual-function-keys.yaml".text = ''
        MAPPINGS:
          - KEY: KEY_CAPSLOCK
            TAP: KEY_ESC
            HOLD: KEY_LEFTCTRL
      '';
      services.interception-tools = with pkgs.interception-tools-plugins; {
        enable = true;
        plugins = [
          dual-function-keys
        ];
        udevmonConfig = let dir = pkgs.interception-tools; in ''
          - JOB: "${dir}/bin/intercept -g $DEVNODE | ${dual-function-keys}/bin/dual-function-keys -c /etc/dual-function-keys.yaml | ${dir}/bin/uinput -d $DEVNODE"
            DEVICE:
              EVENTS:
                EV_KEY: [KEY_CAPSLOCK, KEY_ESC]
        '';
      };
    } ++
    mkListIf cfg.networking {
      networking = {
        networkmanager.enable = true;
      };

      persist.system = {
        directories = [
          "/etc/NetworkManager/system-connections"
        ];
      };
    } ++
    mkListIf cfg.printing {
      services.printing.enable = true;
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };
    } ++
    mkListIf cfg.adb {
      services.udev.packages = [
        pkgs.android-udev-rules
      ];
    } ++
    mkListIf cfg.ssh {
      programs.ssh = {
        startAgent = true;
      };
    } ++
    mkListIf cfg.flatpak {
      services.flatpak.enable = true;
    } ++
    mkListIf cfg.personal-gaming {
      nixpkgs.allowUnfreePkgs = [
        "steam" "steam-original" "steam-run"
      ];

      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
      };
    }
  );
}