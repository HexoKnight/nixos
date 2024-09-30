{
  device ? throw "Set this to your disk device, e.g. /dev/sda",
  swapSize ? "16G",
}:
let
  btrfsCompMntOpts = [ "compress-force=zstd:3" ];
in
{
  disko.devices = {
    disk.main = {
      inherit device;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            name = "boot";
            size = "1M";
            type = "EF02";
          };
          esp = {
            name = "ESP";
            size = "500M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            name = "root";
            size = "100%";
            content = {
              type = "lvm_pv";
              vg = "root_vg";
            };
          };
        };
      };
    };
    lvm_vg = {
      root_vg = {
        type = "lvm_vg";
        lvs = {
          ${if swapSize == null then null else "swap"} = {
            size = swapSize;
            content = {
              type = "swap";
              resumeDevice = true;
            };
          };
          root = {
            size = "100%FREE";
            content = {
              type = "btrfs";
              extraArgs = ["-f"];

              subvolumes = {
                "/root" = {
                  mountOptions = btrfsCompMntOpts ++ [ "noatime" ];
                  mountpoint = "/";
                };
                "/old_roots" = {};

                "/persist" = {
                  mountOptions = btrfsCompMntOpts ++ [ "noatime" ];
                  mountpoint = "/persist";
                };

                "/nix" = {
                  mountOptions = btrfsCompMntOpts ++ [ "noatime" ];
                  mountpoint = "/nix";
                };
              };
            };
          };
        };
      };
    };
  };
}
