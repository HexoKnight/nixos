{
  lib,
  pkgs,
  config,
  ...
}:

let
  httpPort = 8096;
  # httpsPort = 8920;

  cfg = config.services.jellyfin;
in
{
  config = {
    persist.system = {
      directories = [
        {
          directory = cfg.dataDir;
          mode = "700";
          inherit (cfg) user group;
        }
      ];
    };

    users.users.${config.setups.config.username}.extraGroups = [ cfg.group ];

    nginx.hosts.jfin = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${lib.toString httpPort}";
      };
    };
    dnsRecords.jfin.record = {
      type = "CNAME";
      name = "jfin";
      content = "raw.@";
      proxied = true;
    };

    services.jellyfin = {
      enable = true;

      # defaults for reference
      configDir = "${cfg.dataDir}/config";
      logDir = "${cfg.dataDir}/log";

      transcoding.deleteSegments = false;
      forceEncodingConfig = false;

      # as determined by the server's hardware
      hardwareAcceleration = {
        enable = true;
        type = "vaapi";
        device = "/dev/dri/by-path/pci-0000:00:02.0-render";
      };
      # $ nix shell nixpkgs#libva-utils -c vainfo --display drm --device /dev/dri/renderD128
      transcoding = {
        enableHardwareEncoding = true;
        hardwareDecodingCodecs = {
          h264 = true;
          # due to a nixpkgs? bug (should be mpeg2video), needs to set imperatively
          mpeg2 = true;
          vc1 = true;
          vp9 = true;
          # nixpkgs bug so needs to set imperatively
          # see: https://github.com/NixOS/nixpkgs/pull/520045
          # hevc10bit = false;
          # no nix option so needs to set imperatively
          # vp910bit = false;
        };
      };
    };

    # see: https://wiki.nixos.org/wiki/Jellyfin#VAAPI_and_Intel_QSV
    # the processor for this machine is the Intel Core i5-4590:
    # https://www.intel.com/content/www/us/en/products/sku/80815/intel-core-i54590-processor-6m-cache-up-to-3-70-ghz/specifications.html
    nixpkgs.config.packageOverrides = pkgs: {
      intel-vaapi-driver = pkgs.intel-vaapi-driver.override { enableHybridCodec = true; };
    };
    systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "i965";
    environment.sessionVariables.LIBVA_DRIVER_NAME = "i965";
    hardware.graphics = {
      enable = true;

      extraPackages = [
        pkgs.intel-ocl # Generic OpenCL support

        pkgs.intel-vaapi-driver
        pkgs.libva-vdpau-driver

        pkgs.intel-compute-runtime-legacy1
      ];
    };

    nixpkgs.allowUnfreePkgs = [ "intel-ocl" ];
  };
}
