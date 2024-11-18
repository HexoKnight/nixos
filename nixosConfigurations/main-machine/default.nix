{ config, lib, pkgs, inputs, config_name, ... }:

let
  username = "harvey";
in
{
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.asus-zephyrus-ga502
  ];

  setups = {
    config = {
      inherit username;
      hostname = "HARVEY";
      device = "/dev/nvme0n1";
      extraUserOptions = {
        description = "Harvey Gream";
      };
    };
    impermanence = true;
    personal-gaming = true;
    printing = true;
    adb = true;
    flatpak = true;
  };

  host-config.disable-touchpad = "elan1205:00-04f3:30e9-touchpad";

  fileSystems."/c_drive" = {
    device = "/dev/nvme0n1p3";
    fsType = "ntfs3";
    options = [
      # in case it's confusing this actually means
      # the filesystem failing to mount won't cause
      # the boot to fail
      "nofail"
      "uid=1000"
      "gid=100"
    ];
  };

  userhome-config.${username}.extraHmConfig =
    { pkgs, ... }:
    {
      setups.google-chrome.xwayland = true;

      setups.rust.enable = true;
      setups.jupyter.enable = true;
    };

  syncthing = {
    enable = true;
    inherit username;
    settings = {
      devices."Swift 2".id = "CWYRKMN-CSQXLVO-EJXUNGJ-WMFBR3G-UTIME5C-EA4FAKU-OMT4E2S-5OHECQU";
      folders = {
        "Swift 2 Camera" = {
          id = "swift_2_camera";
          path = "/home/${username}/Documents/Phone/Camera";
          devices = [ "Swift 2" ];
        };
        "Swift 2 Downloads" = {
          id = "swift_2_downloads";
          path = "/home/${username}/Documents/Phone/Downloads";
          devices = [ "Swift 2" ];
        };
        "Swift 2 Pictures" = {
          id = "swift_2_pictures";
          path = "/home/${username}/Documents/Phone/Pictures";
          devices = [ "Swift 2" ];
        };
      };
    };
  };

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  services.tlp = {
    enable = true;
    settings = {
      # pretty sure this doesn't work on asus
      START_CHARGE_THRESH_BAT0 = 50;
      # but this is supposed to :/
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };

  services.supergfxd = {
    enable = true;
    settings = {};
  };

  services.asusd = {
    enable = true;
    enableUserService = true;
    asusdConfig = ''
      (
        charge_control_end_threshold: 80,
        panel_od: true,
      )
    '';
  };

  nixpkgs.allowUnfreePkgs = [
    "nvidia-x11" "nvidia-settings"
  ];

  hardware.nvidia = {
    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
    # of just the bare essentials.
    powerManagement.enable = false;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of
    # supported GPUs is at:
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    # Only available from driver 515.43.04+
    # Currently alpha-quality/buggy, so false is currently the recommended setting.
    open = false;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}
