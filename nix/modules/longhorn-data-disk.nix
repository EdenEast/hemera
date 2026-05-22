{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.hemera.longhornDataDisk;
in {
  options.hemera.longhornDataDisk = {
    enable = lib.mkEnableOption "a dedicated Longhorn data disk mounted on this Cluster Node";

    device = lib.mkOption {
      type = lib.types.str;
      default = "/dev/disk/by-id/virtio-longhorn-data";
      description = "Stable device path for the dedicated Longhorn data disk.";
    };

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/longhorn";
      description = "Mount point consumed by Longhorn for replica data.";
    };

    fsType = lib.mkOption {
      type = lib.types.str;
      default = "ext4";
      description = "Filesystem type to create and mount on the Longhorn data disk.";
    };

    label = lib.mkOption {
      type = lib.types.str;
      default = "longhorn-data";
      description = "Filesystem label applied when the Longhorn data disk is first formatted.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.longhorn-data-disk-format = {
      description = "Format the dedicated Longhorn data disk if it is empty";
      wantedBy = ["local-fs-pre.target"];
      before = ["local-fs.target"];
      unitConfig.DefaultDependencies = false;
      path = [
        pkgs.e2fsprogs
        pkgs.util-linux
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu

        if [ ! -b "${cfg.device}" ]; then
          echo "Longhorn data disk ${cfg.device} does not exist" >&2
          exit 1
        fi

        if blkid "${cfg.device}" >/dev/null 2>&1; then
          echo "Longhorn data disk ${cfg.device} already has a filesystem; leaving it unchanged"
          exit 0
        fi

        mkfs.${cfg.fsType} -F -L "${cfg.label}" "${cfg.device}"
      '';
    };

    fileSystems.${cfg.mountPoint} = {
      device = cfg.device;
      fsType = cfg.fsType;
      options = [
        "nofail"
        "x-systemd.requires=longhorn-data-disk-format.service"
        "x-systemd.after=longhorn-data-disk-format.service"
      ];
    };
  };
}
