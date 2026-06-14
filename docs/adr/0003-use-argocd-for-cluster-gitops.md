# Use Argo CD for cluster GitOps

Hemera will use Argo CD as its in-cluster GitOps controller because the operator experience, UI, visual diff, and sync workflow are more valuable for this homelab than Flux's more Kubernetes-native Helm and source primitives. Node Management remains outside Argo CD, while Cluster Resources are handed to Argo CD after bootstrap through a GitOps Root Application that points at a cluster-specific Cluster Entry Point.

## Consequences

- Terraform, NixOS, Colmena, and k3s bootstrap remain operator-run Node Management.
- Initial Sealed Secrets installation/key restore is the first cluster bootstrap step so sealed Argo CD credentials can be restored from git during disaster recovery.
- Initial Argo CD installation and GitOps Root Application creation remain bootstrap steps to avoid a GitOps dependency loop.
- After GitOps Handoff, Argo CD owns Cluster Resources, including Sealed Secrets, Argo CD configuration, storage, operators, access components, and applications.
- GitOps Components are Kustomize paths; Helm-backed components are rendered through Kustomize rather than Helmfile.
- Argo CD itself is installed from the Argo CD Helm chart rendered by Kustomize.
- GitOps Components declare their namespace in local `kustomization.yaml` files and include explicit Namespace manifests when they own the namespace.
- Hemera starts with area-level Argo CD Applications for repository areas such as `storage/`, `operators/`, `access/`, and `apps/`.
- Argo CD syncs remain manual during the initial migration, and pruning is disabled until the operator explicitly enables it later.
- Area-level Applications declare sync waves to encode intended reconciliation order even while the operator performs syncs manually.
