# Use Flux for Kubernetes reconciliation

Hemera will use Flux as the GitOps Controller for Kubernetes resources after k3s is bootstrapped. Terraform remains responsible for Proxmox VM lifecycle and Colmena remains responsible for Node Operating System configuration and k3s bootstrap, because letting Flux cross that boundary would blur recovery ownership and make early cluster creation depend on a controller that does not exist yet.

## Consequences

- `clusters/k3s/` is the Flux entrypoint for in-cluster reconciliation.
- Helmfile remains a temporary fallback, not the normal deployment mechanism.
- Flux adopts existing Helm releases in place with exact chart versions.
- Storage reconciliation uses `prune: false`; other areas use pruning.
