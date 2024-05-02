{ username,
  hostName,
  device,
  dual-boot ? false,
  impermanence ? false,
}:

{ config, lib, pkgs, inputs, config_name, ... }:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
    (import ./syncthing.nix { inherit username; })
  ] ++ (lib.lists.optionals impermanence [
    inputs.disko.nixosModules.default
    (import ../impermanence-disko.nix { inherit device; })
    inputs.impermanence.nixosModules.impermanence
    (import ../impermanence.nix { inherit lib; })
  ]);

  sops.defaultSopsFile = "${inputs.self}/secrets.json";
  sops.defaultSopsFormat = "json";

  sops.gnupg.sshKeyPaths = [];
  sops.age.sshKeyPaths = [];
  sops.age.keyFile = (if impermanence then "/persist" else "") + "/home/${username}/.config/sops/agekey";

  sops.secrets.hashedPassword = {
    neededForUsers = true;
  };

  # Bootloader.
  boot.loader = {
    grub.enable = true;
    grub.useOSProber = true;
    grub.device = device;
  } // (lib.mkIf dual-boot {
    grub.devices = [ "nodev" ];
    grub.efiSupport = true;
    grub.timestampFormat = "%F %H:%M";
    efi.canTouchEfiVariables = true;
  });

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.channel.enable = false; # only flakes :)

  # allows 'normal' UNIX shebangs (eg. #!/bin/bash)
  services.envfs.enable = true;

  networking.hostName = hostName;
  services.xrdp = {
    enable = true;
    defaultWindowManager = "startplasma-x11";
    openFirewall = true;
  };

  networking.networkmanager.enable = true;
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.wireless.networks = {};

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.xserver.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "where_is_my_sddm_theme_qt5";
    settings = {
    };
  };
  # services.xserver.desktopManager.plasma5.enable = true;
  # environment.plasma5.excludePackages = with pkgs.libsForQt5; [
  #   oxygen
  # ];

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  };

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  host-config = {
    mutableUsers = false;
    desktop = true;
  };
  userhome-config.${username} = {
    cansudo = true;
    persistence = true;
    personal-gaming = true;
    extraOptions = {
      isNormalUser = true;
      description = "Harvey Gream";
      hashedPasswordFile = config.sops.secrets.hashedPassword.path;
    };
  };
  # for adb
  services.udev.packages = [
    pkgs.android-udev-rules
  ];

  environment.variables = {
    # This is not very pure but only nixos-rebuild scripts depend on it
    # so they'll just fail harmlessly when run if there's nothing there.
    # To be entirely honest I'd rather this just be impure but oh well...
    NIXOS_BUILD_DIR = "/home/${username}/.nixos";
    NIXOS_BUILD_CONFIGURATION = config_name;
  };
  environment.etc = {
    nixos-current-system-source.source = inputs.self;
  };

  programs.ssh = {
    startAgent = true;
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

    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [
      "nvidia-x11" "nvidia-settings"
      "steam" "steam-original" "steam-run"
    ];
  environment.systemPackages = with pkgs; [
    (libsForQt5.callPackage "${inputs.self}/packages/where-is-my-sddm-theme-qt5.nix" {
      # variants = [ "qt6" "qt5" ];
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

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

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

  services.openssh.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
