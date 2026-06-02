# Use NixOS cloud-init, Colmena, and k3s for Cluster Nodes

Hemera will use NixOS as the Cluster Node operating system, `services.cloud-init` only for first boot reachability, Colmena for applying full NixOS host configuration, and k3s for Kubernetes. This keeps the operator on the Linux distribution they are most comfortable debugging while avoiding the previous bootstrap trap where Terraform, NixOS activation, host identity, and sops-nix secrets all depended on each other too early.

## Considered Options

- Talos-managed Kubernetes: cleaner immutable node lifecycle, but too large a shift for this rebuild.
- Debian 12 cloud with Ansible: industry-common and straightforward, but less comfortable for the operator than NixOS.
- Previous NixOS + direct `nixos-rebuild` + sops-nix host recipients: reproducible, but startup and secrets sequencing felt hacky.

## Consequences

- Terraform owns Proxmox VM lifecycle, not k3s installation.
- Cloud-init is restricted to First Boot Configuration and must not carry cluster secrets or full install logic.
- Colmena becomes the Bootstrap Step for host configuration.
- The k3s join token stays in the cluster and is copied to joining nodes over SSH during bootstrap, not stored in Terraform state, cloud-init metadata, or a repository secret file.
- The first Control Plane Node initializes k3s with embedded etcd so future Control Plane Nodes can join later.
