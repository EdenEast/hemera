{...}: {
  imports = [
    ../../modules/common.nix
    ../../modules/k3s-agent.nix
  ];

  networking = {
    hostName = "k8s-worker-02";
    useDHCP = false;
    defaultGateway = "192.168.1.1"; # TODO_CONFIRM
    nameservers = ["192.168.1.1"]; # TODO_CONFIRM
    interfaces.ens18.ipv4.addresses = [
      {
        address = "192.168.1.52"; # TODO_CONFIRM
        prefixLength = 24; # TODO_CONFIRM
      }
    ];
  };

  system.stateVersion = "26.05";
}
