# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, unstable-overlay, config_name, ... }:

{
  disabledModules = [ "services/networking/xrdp.nix" ];
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
    "${inputs.nixpkgs-unstable}/nixos/modules/services/networking/xrdp.nix"
  ];
  nixpkgs.overlays = [ unstable-overlay ];

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.channel.enable = false; # only flakes :)

  # allows 'normal' UNIX shebangs (eg. #!/bin/bash)
  services.envfs.enable = true;

  networking.hostName = "HARVEY-nixos"; # Define your hostname.
  networking.interfaces.eno1.wakeOnLan = {
    enable = false;
    policy = [ "magic" ];
  };
  services.xrdp = {
    enable = true;
    package = pkgs.unstable.xrdp;
    audio.enable = true;
    audio.package = pkgs.unstable.pulseaudio-module-xrdp;
    defaultWindowManager = "startplasma-x11";
    openFirewall = true;
  };

  networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.wireless.networks = {
    TP-Link_7830 = {
      psk = "ba9519617802dc29032dbd5ead2c05114ecf1d745364106f740d0e97d3aacca5";
    };
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  # networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/London";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;

  # Configure keymap in X11
  services.xserver = {
    layout = "gb";
    xkbVariant = "";
  };

  # Configure console keymap
  console.keyMap = "uk";

  # Enable CUPS to print documents.
  services.printing.enable = true;

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

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  users.mutableUsers = false;
  users.groups = {
    wheel = {};
    users = {};
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.harvey = {
    isNormalUser = true;
    description = "Harvey Gream";
    extraGroups = [ "wheel" ];
    hashedPasswordFile = "${inputs.self}/secrets/hashed_password";

    packages = with pkgs; [
      (writeShellScriptBin "rebuild" (builtins.readFile ../../rebuild.sh)
        #./rebuild.sh
      )
      # required for the rebuild command
      (writeShellScriptBin "evalvar" (builtins.readFile ../../evalvar.sh))
      # for 
      unstable.nixVersions.nix_2_19
    ];
  };

  environment.variables = {
    # This is not very pure but only nixos-rebuild scripts depend on it
    # so they'll just fail harmlessly when run if there's nothing there.
    # To be entirely honest I'd rather this just be impure but oh well...
    NIXOS_BUILD_DIR = "/home/harvey/.nixos";
    NIXOS_BUILD_CONFIGURATION = config_name;
  };

  programs.ssh = {
    startAgent = true;
  };

  home-manager = {
    extraSpecialArgs = {inherit inputs unstable-overlay;};
    users = {
      "harvey" = import ./home.nix;
    };
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

  # Allow unfree packages
  #nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
  ];

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

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?

}
