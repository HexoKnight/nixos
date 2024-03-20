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

  networking.hostName = "HARVEY-nixos";
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

  users.mutableUsers = false;
  users.groups = {
    wheel = {};
    users = {};
  };

  users.users.harvey = {
    isNormalUser = true;
    description = "Harvey Gream";
    extraGroups = [ "wheel" ];
    hashedPasswordFile = "${inputs.self}/secrets/hashed_password";

    packages = with pkgs; [
      (writeShellScriptBin "rebuild" (builtins.readFile /.${inputs.self}/rebuild.sh))

      # required for the rebuild command
      (writeShellScriptBin "evalvar" (builtins.readFile /.${inputs.self}/evalvar.sh))
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
    users.harvey = import /.${inputs.self}/modules/home.nix;
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

  environment.systemPackages = with pkgs; [
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

  services.openssh.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
