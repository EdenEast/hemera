{config, ...}: {
  networking.firewall.allowedTCPPorts = [9100 10250];
  networking.firewall.allowedUDPPorts = [8472];
  networking.firewall.trustedInterfaces = ["cni0" "flannel.1"];

  services.k3s = {
    enable = true;
    role = "agent";
    serverAddr = "https://192.168.2.50:6443";
    tokenFile = "/var/lib/rancher/k3s/cluster-token";
    nodeName = config.networking.hostName;
    extraFlags = [
      "--node-label=node.longhorn.io/create-default-disk=true"
    ];
  };
}
