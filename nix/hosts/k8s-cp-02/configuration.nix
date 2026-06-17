{...}: {
  imports = [
    ../../modules/common.nix
    ../../modules/k3s-server.nix
  ];

  services.k3s.serverAddr = "https://192.168.2.50:6443";

  networking = {
    hostName = "k8s-cp-02";
    interfaces.eth0.ipv4.addresses = [
      {
        address = "192.168.2.56";
        prefixLength = 24;
      }
    ];
  };
}
