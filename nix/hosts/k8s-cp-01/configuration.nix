{...}: {
  imports = [
    ../../modules/common.nix
    ../../modules/k3s-server.nix
  ];

  networking = {
    hostName = "k8s-cp-01";
    useDHCP = false;
    defaultGateway = "192.168.2.1";
    nameservers = ["192.168.2.1"];
    interfaces.ens18.ipv4.addresses = [
      {
        address = "192.168.2.81";
        prefixLength = 24;
      }
    ];
  };
}
