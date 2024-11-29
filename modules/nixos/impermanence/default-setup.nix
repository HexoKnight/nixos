{ lib, inputs, pkgs, config, ... }:

let
  inherit (lib) mkEnableOption mkOption;

  cfg = config.persist.defaultSetup;

  # https://btrfs.readthedocs.io/en/latest/Compression.html
  # purposefully forces specification of compression level
  btrfsCompressionTypes = lib.concatLists (
    lib.mapAttrsToList (name: levels:
      if levels == null then
        [ name ]
      else
        lib.genList (i: "${name}:${toString (i + 1)}") levels
    ) {
      zlib = 9;
      lzo = null;
      zstd = 15;
    }
  );
in
{
  options.persist.defaultSetup = {
    enable = mkEnableOption "the default impermanence setup (disko, wipe on boot, etc.), see the source for details";
    device = mkOption {
      description = "The disk used by disko.";
      type = inputs.disko.lib.optionTypes.absolute-pathname;
    };
    swapSize = mkOption {
      description = "The amount of swap allocated by disko.";
      type = lib.types.str;
      default = "16G";
    };
    btrfsCompression = mkOption {
      description = "The type of compresion to use on the main btrfs filesystem.";
      type = lib.types.nullOr (lib.types.enum btrfsCompressionTypes);
      default = "zstd:3";
    };
  };

  config = lib.mkIf (config.persist.enable && cfg.enable) {
    persist.root = "/persist";

    disko = (import ./disko.nix {
      inherit (cfg) device swapSize btrfsCompression;
    }).disko;

    fileSystems."/persist".neededForBoot = true;

    # straight from impermanence repo: https://github.com/nix-community/impermanence#btrfs-subvolumes
    # adapted to use a subvolume for `old_roots` (but nothing actually needed to change)
    boot.initrd.postDeviceCommands = lib.mkAfter /* bash */ ''
      mkdir /btrfs_tmp
      mount /dev/root_vg/root /btrfs_tmp
      if [[ -e /btrfs_tmp/root ]]; then

          # delete stuff that fills up quick
          rm -r /btrfs_tmp/root/home/*/.cache
          rm -r /btrfs_tmp/root/var/lib/systemd/coredump

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

      for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +14); do
          delete_subvolume_recursively "$i"
      done

      btrfs subvolume create /btrfs_tmp/root
      umount /btrfs_tmp
    '';

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "mount-oldroots" ''
        mkdir -p /old_roots &&
        mount /dev/root_vg/root /old_roots -o subvol=/old_roots,ro,noatime "$@"
      '')
    ];

    # sudo message plays after every roboot otherwise
    security.sudo.extraConfig = ''
      Defaults  lecture="never"
    '';
  };
}
