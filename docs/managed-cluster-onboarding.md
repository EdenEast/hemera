# Managed Cluster Onboarding

This runbook describes how Hemera's Control Cluster can reconcile a future Managed Cluster without installing a separate Argo CD instance there.

## Topology terms

- **Control Cluster**: the Kubernetes cluster where Hemera's active Argo CD instance runs.
- **Managed Cluster**: a Kubernetes cluster reconciled by Hemera's Argo CD instance.
- **Self-Managed Cluster**: a cluster that both runs Argo CD and is reconciled by that same Argo CD instance. The current `clusters/k3s` entrypoint is Self-Managed.

## Onboarding model

1. Build the new Managed Cluster with its own Node Management and Bootstrap Steps.
2. Create a restricted Kubernetes credential for Argo CD in the Managed Cluster. Scope it to the namespaces and cluster resources that the Control Cluster should reconcile.
3. Store that credential as an Argo CD cluster Secret in the **Control Cluster** `argocd` namespace. The Secret must use Argo CD's cluster secret label:

   ```yaml
   metadata:
     labels:
       argocd.argoproj.io/secret-type: cluster
   ```

4. Seal the cluster credential with the **Control Cluster** Sealed Secrets certificate, because the Secret is decrypted and used by Argo CD in the Control Cluster. Do not seal it with the Managed Cluster certificate.
5. Add a sibling Cluster Entry Point when the Managed Cluster is ready, for example `clusters/<managed-cluster-name>/kustomization.yaml`.
6. Add or update an Argo CD Application in the Control Cluster that points at the new sibling Cluster Entry Point and has the Managed Cluster as its destination.

## Notes

- A Managed Cluster does not need its own Argo CD install unless it becomes a separate Control Cluster later.
- The current repository does not need generic overlays before a second cluster exists. Add sibling Cluster Entry Points when concrete cluster differences are known.
- Keep manual sync and no-prune defaults for new Managed Cluster Applications until the operator has reviewed the first diffs.
