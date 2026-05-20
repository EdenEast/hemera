# Use NixOS for Kubernetes node configuration

Hemera uses NixOS configurations applied with `nixos-rebuild --target-host` to configure Kubernetes node VMs instead of Ansible, Terraform provisioners, or ad-hoc bootstrap scripts. This keeps Terraform focused on Proxmox VM lifecycle while making operating-system and k3s node state declarative and reproducible, at the cost of a higher initial NixOS learning curve.

## Consequences

- Terraform owns VM creation, sizing, disks, and network attachment only.
- NixOS owns users, SSH, static networking, secrets integration, and k3s services.
- Colmena can be introduced later if direct `nixos-rebuild --target-host` becomes too limited.
