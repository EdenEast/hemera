{...}: {
  imports = [
    ../../modules/common.nix
    ../../modules/k3s-agent.nix
    ../../modules/longhorn-data-disk.nix
  ];

  hemera.longhornDataDisk.enable = true;

  networking = {
    hostName = "k8s-worker-02";
    useDHCP = false;
    defaultGateway = "192.168.2.1";
    nameservers = ["192.168.2.1"];
    interfaces.eth0.ipv4.addresses = [
      {
        address = "192.168.2.83";
        prefixLength = 24;
      }
    ];
  };

  system.stateVersion = "26.05";
}
