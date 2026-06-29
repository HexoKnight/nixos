let
  subvolMountOptions = [
    # 15 is not much better but really slow
    "compress-force=zstd:8"
    "noatime"
  ];
in
{
  disko.devices = {
    disk.extra-storage = {
      device = "/dev/disk/by-id/ata-WDC_WD10SPCX-24HWST1_WD-WX91A9424Y7L";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          main = {
            name = "main";
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];

              subvolumes = {
                "/storage" = {
                  mountOptions = subvolMountOptions;
                  mountpoint = "/external/storage";
                };
              };
            };
          };
        };
      };
    };
  };
}
