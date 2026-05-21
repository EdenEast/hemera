{config, ...}: {
  networking.firewall = {
    allowedTCPPorts = [
      # Kubernetes API server. Workers and admin workstations use this to
      # join/manage the cluster.
      6443

      # Kubelet HTTPS API. Required for control-plane operations such as
      # logs, exec, and metrics-server scraping node metrics.
      10250
    ];

    # Flannel VXLAN overlay traffic between Cluster Nodes.
    allowedUDPPorts = [8472];

    # Pod/overlay interfaces are managed by k3s/flannel; trust them so pod and
    # service traffic is not blocked by the host firewall.
    trustedInterfaces = [
      "cni0"
      "flannel.1"
    ];
  };

  services.k3s = {
    enable = true;
    role = "server";
    tokenFile = config.sops.secrets."k3s/token".path;
  };
}
