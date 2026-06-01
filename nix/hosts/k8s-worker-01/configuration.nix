{...}: {
  imports = [
    ../../modules/common.nix
    ../../modules/k3s-agent.nix
    ../../modules/longhorn-data-disk.nix
  ];

  hemera.longhornDataDisk.enable = true;

  networking = {
    hostName = "k8s-worker-01";
    useDHCP = false;
    defaultGateway = "192.168.2.1";
    nameservers = [
      "192.168.2.1"
      "1.1.1.1"
      "9.9.9.9"
    ];
    interfaces.eth0.ipv4.addresses = [
      {
        address = "192.168.2.82";
        prefixLength = 24;
      }
    ];
  };
}
