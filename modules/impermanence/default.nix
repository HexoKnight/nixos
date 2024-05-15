{ device }:

{ lib, inputs, pkgs, ... }:

{
  imports = [
    inputs.disko.nixosModules.default
    (import ./disko.nix { inherit device; })
    inputs.impermanence.nixosModules.impermanence
  ];

  # straight from impermanence repo: https://github.com/nix-community/impermanence#btrfs-subvolumes
  # adapted to use a subvolume for `old_roots` (but nothing actually needed to change)
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    mkdir /btrfs_tmp
    mount /dev/root_vg/root /btrfs_tmp
    if [[ -e /btrfs_tmp/root ]]; then
        mkdir -p /btrfs_tmp/old_roots
        timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%d_%H:%M:%S")
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

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "mount-oldroots" ''
      if [ -n "$OLD_ROOTS_RW" ]; then rtype=rw
      else rtype=ro
      fi

      mkdir -p /old_roots &&
      mount /dev/root_vg/root /old_roots -o subvol=/old_roots,''${rtype},noatime
    '')
  ];

  fileSystems."/persist".neededForBoot = true;
  environment.persistence."/persist/system" = {
    hideMounts = true;
    directories = [
      "/etc/NetworkManager/system-connections"
      "/var/lib/systemd/timers"
    ];
    files = [
      "/etc/machine-id"
    ];
  };

  # sudo message plays after every roboot otherwise
  security.sudo.extraConfig = ''
    Defaults  lecture="never"
  '';
}
