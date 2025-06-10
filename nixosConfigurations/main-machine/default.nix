{ config, lib, pkgs, config_name, ... }:

let
  username = "harvey";

  syncthingConfigDir = ".config/syncthing";

  obsidianVaultsDir = "Documents/Obsidian";
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  setups = {
    config = {
      inherit username;
      hostname = "HARVEY";
      device = "/dev/nvme0n1";
    };
    impermanence = true;
    personal-gaming = true;
    printing = true;
    android = true;
    flatpak = true;
  };

  fileSystems."/c_drive" = {
    device = "/dev/disk/by-uuid/AC5C11195C10DFBE";
    fsType = "ntfs3";
    options = [
      # in case it's confusing this actually means
      # the filesystem failing to mount won't cause
      # the boot to fail
      "nofail"
      "uid=1000"
      "gid=100"
      "noatime"

      "windows_names"
    ];
  };

  disko = (import ./disko.nix).disko;

  home-manager.users.${username} =
    { pkgs, ... }:
    {
      setups.config.disable-touchpad = "elan1205:00-04f3:30e9-touchpad";
      setups.google-chrome.xwayland = true;

      setups.rust.enable = true;
      setups.jupyter.enable = true;
      setups.obsidian = {
        enable = true;
        plugin.workspaces = {
          vault.path = "~/Documents/Obsidian/vault";
        };
        plugin.findWorkspaces = /* lua */ ''
          local vaults_dir = '~/${obsidianVaultsDir}'
          return vim.iter(vim.fs.dir(vaults_dir))
            :map(function(name, type)
              -- every non-hidden directory
              if type == 'directory' and name:sub(1, 1) ~= '.' then
                return {
                  name = name,
                  path = vaults_dir .. '/' .. name,
                }
              end
            end)
            :totable()
        '';
      };

      services.syncthing.tray.enable = true;
      persist-home.files = [
        ".config/syncthingtray.ini"
      ];
    };

  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true"; # Don't create default ~/Sync folder
  services.syncthing = {
    enable = true;

    user = username;
    group = config.users.users.${username}.group;

    dataDir = "/home/${username}/${obsidianVaultsDir}";
    configDir = "/home/${username}/${syncthingConfigDir}";

    overrideDevices = true;
    overrideFolders = false;

    settings = {
      devices."phone" = {
        id = "XNPMAPQ-A5QY7G7-3AVZFLV-IGIM3J3-TAPNA76-AEFZ3DG-FEGUL5B-3HAX4AP";
        autoAcceptFolders = true;
      };
      folders = {
        obsidian = {
          label = "Obsidian";
          path = "/home/${username}/Documents/Obsidian";
          devices = [ "phone" ];

          type = "sendreceive";
        };
      };
      # each top-level option is actually an endpoint
      "defaults/folder" = {
        type = "receiveonly";
        path = "~/Documents/syncthing";
      };
    };
  };
  systemd.tmpfiles.settings.syncthing = {
    ${config.services.syncthing.dataDir}.d = {
      mode = "750";
      inherit (config.services.syncthing) user group;
    };
  };
  persist.users.${username}.directories = [
    syncthingConfigDir
  ];

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  programs.virt-manager.enable = true;
  virtualisation = {
    libvirtd = {
      enable = true;

      qemu = {
        package = pkgs.qemu_kvm;

        ovmf = {
          enable = true;
          packages = [ pkgs.OVMFFull.fd ];
        };

        swtpm.enable = true;
      };
    };
  };

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
    asusdConfig.text = ''
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
