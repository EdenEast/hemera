{config, ...}: {
  networking.firewall.allowedTCPPorts = [10250];
  networking.firewall.allowedUDPPorts = [8472];
  networking.firewall.trustedInterfaces = ["cni0" "flannel.1"];

  services.k3s = {
    enable = true;
    role = "agent";
    serverAddr = "https://192.168.2.81:6443";
    tokenFile = "/var/lib/rancher/k3s/agent-token";
    nodeName = config.networking.hostName;
  };
}
