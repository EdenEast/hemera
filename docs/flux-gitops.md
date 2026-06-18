# Flux GitOps

Hemera uses Flux as the GitOps Controller for in-cluster Kubernetes resources. Terraform owns Proxmox VM lifecycle, Colmena owns Node Operating System configuration and k3s bootstrap, and Flux owns the GitOps Reconciliation Phase after the cluster API is reachable.

## Bootstrap

For a step-by-step migration procedure, see [`flux-migration-runbook.md`](flux-migration-runbook.md).

Bootstrap Flux from the repository root:

```sh
scripts/bootstrap-flux
```

The script runs `flux bootstrap git` against the current Hemera GitHub repository and the `clusters/k3s` path. Flux creates `clusters/k3s/flux-system/` during bootstrap; do not copy generated Flux manifests from another repository.

If rebuilding a cluster that must reuse existing sealed secrets, restore the Sealed Secrets private key before bootstrapping Flux. The private key backup is operator-managed and must not be committed to this repository.

## Reconciliation layout

Flux reconciles top-level areas from `clusters/k3s/`:

```text
infrastructure -> operators
infrastructure -> storage
infrastructure -> access
operators + storage + access -> apps
operators + storage + access -> monitoring
```

`storage` uses `prune: false` to reduce the chance of deleting stateful storage resources accidentally. Other areas use `prune: true`.

Each deployable app or component owns its local `kustomization.yaml` and namespace resources. Helm-managed components use Flux `HelmRepository` and `HelmRelease` resources with exact chart versions matching the current deployed versions.

## Manual fallback

Helmfile and direct `kubectl apply` commands may remain as temporary migration or recovery tools, but Flux is the normal source of truth after bootstrap succeeds. Changes should be made in git and reconciled by Flux rather than applied directly to the live cluster.

For short-lived testing of uncommitted local changes, use an isolated ephemeral development deployment. See [`ephemeral-dev-deployments.md`](ephemeral-dev-deployments.md).
