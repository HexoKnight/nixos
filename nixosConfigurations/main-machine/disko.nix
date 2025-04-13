let
  subvolMountOptions = [
    "nofail"
    # 15 is not much better but really slow
    "compress-force=zstd:8"
    "noatime"
  ];
in
{
  disko.devices = {
    disk.external = {
      device = "/dev/disk/by-id/usb-Micron_CT500X6SSD9_2253E4996869-0:0";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          main = {
            name = "main";
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = ["-f"];

              subvolumes = {
                "/storage" = {
                  mountOptions = subvolMountOptions;
                  mountpoint = "/external/storage";
                };
                "/backup" = {
                  mountOptions = subvolMountOptions;
                  mountpoint = "/external/backup";
                };
              };
            };
          };
        };
      };
    };
  };
}
