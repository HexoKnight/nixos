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
    android = true;
    flatpak = true;

    printing.enable = true;
    podman.enable = true;
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

      setups.tooling.rust.enable = true;
      setups.tooling.jupyter.enable = true;
      setups.tooling.typescript.enable = true;

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

      home.packages = [
        pkgs.haguichi
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

  services.logmein-hamachi.enable = true;

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
    modesetting.enable = true;

    # required for hibernation on hyprland
    powerManagement.enable = true;
    powerManagement.finegrained = false;

    # open kernel modules (different to the nouveau open driver) are recommended nowadays
    open = true;

    nvidiaSettings = true;

    # use latest stable
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}
