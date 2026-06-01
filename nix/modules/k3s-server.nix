{config, ...}: {
  networking.firewall.allowedTCPPorts = [6443 10250];
  networking.firewall.allowedUDPPorts = [8472];
  networking.firewall.trustedInterfaces = ["cni0" "flannel.1"];

  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    nodeName = config.networking.hostName;
    extraFlags = [
      "--write-kubeconfig-mode=0644"
    ];
  };
}
