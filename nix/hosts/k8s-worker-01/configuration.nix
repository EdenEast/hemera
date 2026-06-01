{...}: {
  imports = [
    ../../modules/common.nix
    ../../modules/k3s-agent.nix
    ../../modules/longhorn-data-disk.nix
  ];

  networking = {
    hostName = "k8s-worker-01";
    useDHCP = false;
    defaultGateway = "192.168.2.1";
    nameservers = ["192.168.2.1"];
    interfaces.ens18.ipv4.addresses = [
      {
        address = "192.168.2.82";
        prefixLength = 24;
      }
    ];
  };
}
