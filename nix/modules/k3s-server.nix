{
  config,
  lib,
  ...
}: {
  networking.firewall.allowedTCPPorts = [2379 2380 6443 9100 10250];
  networking.firewall.allowedUDPPorts = [8472];
  networking.firewall.trustedInterfaces = ["cni0" "flannel.1"];

  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = lib.mkDefault false; # Enable this on the host of the first new cluster
    serverAddr = lib.mkDefault "";
    tokenFile = lib.mkDefault "/var/lib/rancher/k3s/cluster-token";
    nodeName = config.networking.hostName;
    extraFlags = [
      "--write-kubeconfig-mode=0644"
      "--node-taint=node-role.kubernetes.io/control-plane=true:NoSchedule"
      "--tls-san=192.168.2.50"
    ];
  };
}
