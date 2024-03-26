{ config, lib, pkgs, inputs, unstable-overlay, config_name, ... }:

let
  username = "harvey";
in {
  imports = [
    ./hardware-configuration.nix
    inputs.disko.nixosModules.default
    (import ./disko.nix { device = "/dev/sda"; })
    inputs.impermanence.nixosModules.impermanence
    inputs.sops-nix.nixosModules.sops
    (import ./syncthing.nix { inherit username; })
  ];

  sops.defaultSopsFile = "${inputs.self}/secrets.json";
  sops.defaultSopsFormat = "json";

  sops.age.keyFile = "/persist/home/${username}/.config/sops/agekey";

  sops.secrets.hashedPassword = {
    neededForUsers = true;
  };

  # Bootloader.
  boot.loader.grub.enable = true;
  # boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    mkdir /btrfs_tmp
    mount /dev/root_vg/root /btrfs_tmp
    if [[ -e /btrfs_tmp/root ]]; then
        mkdir -p /btrfs_tmp/old_roots
        timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
        mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
    fi

    delete_subvolume_recursively() {
        IFS=$'\n'
        for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
            delete_subvolume_recursively "/btrfs_tmp/$i"
        done
        btrfs subvolume delete "$1"
    }

    for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
        delete_subvolume_recursively "$i"
    done

    btrfs subvolume create /btrfs_tmp/root
    umount /btrfs_tmp
  '';

  fileSystems."/persist".neededForBoot = true;
  environment.persistence."/persist/system" = {
    hideMounts = true;
    files = [
      "/etc/machine-id"
    ];
    users.${username} = {
      directories = [
        "Documents"
        ".nixos"
        "dotfiles"
        ".vim"
        ".config"
        ".ssh"
      ];
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.channel.enable = false; # only flakes :)

  # allows 'normal' UNIX shebangs (eg. #!/bin/bash)
  services.envfs.enable = true;

  networking.hostName = "HARVEY-nixos";
  networking.interfaces.eno1.wakeOnLan = {
    enable = false;
    policy = [ "magic" ];
  };
  services.xrdp = {
    enable = true;
    defaultWindowManager = "startplasma-x11";
    openFirewall = true;
  };

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.wireless.networks = {};

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;

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
      "steam" "steam-original" "steam-run"
    ];
  environment.systemPackages = with pkgs; [
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
