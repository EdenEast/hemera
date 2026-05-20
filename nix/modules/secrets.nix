{...}: {
  sops.defaultSopsFile = ../secrets/k3s.yaml;

  # Host age identities are derived from each Cluster Node's unique SSH host key.
  # The NixOS Proxmox template must not include pre-generated SSH host keys.
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  sops.secrets."k3s/token" = {
    path = "/run/secrets/k3s-token";
    mode = "0400";
  };
}
