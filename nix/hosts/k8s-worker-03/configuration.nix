{...}: {
  imports = [
    ../../modules/common.nix
    ../../modules/k3s-agent.nix
    ../../modules/longhorn-data-disk.nix
  ];

  hemera.longhornDataDisk.enable = true;

  networking = {
    hostName = "k8s-worker-03";
    interfaces.eth0.ipv4.addresses = [
      {
        address = "192.168.2.59";
        prefixLength = 24;
      }
    ];
  };
}
