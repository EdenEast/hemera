{pkgs, ...}: {
  boot.kernelModules = ["iscsi_tcp"];

  systemd.services.longhorn-data-disk-format = {
    description = "Format Longhorn data disk if empty";
    wantedBy = ["local-fs-pre.target"];
    before = ["local-fs.target"];
    unitConfig.DefaultDependencies = false;
    path = [pkgs.e2fsprogs pkgs.util-linux];
    serviceConfig.Type = "oneshot";
    script = ''
      set -eu
      device=/dev/disk/by-id/virtio-longhorn-data
      test -b "$device"
      if ! blkid "$device" >/dev/null 2>&1; then
        mkfs.ext4 -F -L longhorn-data "$device"
      fi
    '';
  };

  fileSystems."/var/lib/longhorn" = {
    device = "/dev/disk/by-id/virtio-longhorn-data";
    fsType = "ext4";
    options = [
      "nofail"
      "x-systemd.requires=longhorn-data-disk-format.service"
      "x-systemd.after=longhorn-data-disk-format.service"
    ];
  };
}
