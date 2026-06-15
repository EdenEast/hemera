# Argo CD Migration Runbook

This runbook migrates the existing Hemera Self-Managed Cluster from the Manual Apply Phase to the Argo CD GitOps Managed Phase.

Use `docs/argocd-bootstrap.md` for brand-new cluster bootstrap, Control Cluster rebuilds, and Managed Cluster onboarding. This document focuses on migrating the current live cluster without intentionally changing Node Management.

## Migration goals

- Keep Terraform, NixOS, Colmena, and k3s outside Argo CD.
- Move Cluster Resources to Argo CD ownership.
- Keep initial sync manual and pruning disabled.
- Use Kustomize with `--enable-helm` for every GitOps Component.
- Preserve existing namespaces, PVCs, Sealed Secrets, and workload resources.

## Preparation

### 1. Enter the development shell

```sh
nix develop
```

The shell provides `kubectl`, `kustomize`, `argocd`, `kubeseal`, `helm`, and the project helper scripts.

### 2. Confirm kubeconfig points at the intended cluster

```sh
kubectl config current-context
kubectl get nodes -o wide
kubectl get pods -A
```

Do not proceed if the context is not the Hemera Self-Managed Cluster.

### 3. Review the GitOps decision and topology terms

Read:

- `CONTEXT.md`
- `docs/adr/0003-use-argocd-for-cluster-gitops.md`
- `docs/argocd-bootstrap.md`

### 4. Prepare the Argo CD repository credential

Argo CD needs read access to this repository. Use a dedicated read-only deploy key.

1. Create a deploy key for `EdenEast/hemera`.
2. Add the public key to the repository with read-only access.
3. Create a local Secret from the example:

   ```sh
   cp infrastructure/argocd/bootstrap/repo-credential.secret.example.yaml /tmp/hemera-repo.secret.yaml
   $EDITOR /tmp/hemera-repo.secret.yaml
   ```

4. Seal it with the current cluster's Sealed Secrets public certificate:

   ```sh
   kubeseal --fetch-cert > infrastructure/sealed-secrets/pub-cert.pem
   kubeseal --format yaml \
     --cert infrastructure/sealed-secrets/pub-cert.pem \
     < /tmp/hemera-repo.secret.yaml \
     > infrastructure/argocd/bootstrap/repo-credential.sealed.yaml
   rm /tmp/hemera-repo.secret.yaml
   ```

5. Uncomment `repo-credential.sealed.yaml` in `infrastructure/argocd/bootstrap/kustomization.yaml`.

### 5. Back up the Sealed Secrets private key

Before changing how Sealed Secrets is managed, back up the controller key outside git:

```sh
kubectl -n kube-system get secret \
  -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o yaml > sealed-secrets-private-key.backup.yaml
```

Store the backup in secure storage. Do not commit it.

### 6. Commit and push migration manifests

The Argo CD root Application currently targets `main`, so the migration manifests must be available on `main` before Argo CD can reconcile them.

If testing from a branch, temporarily change `targetRevision` in the Argo CD Application manifests to that branch and change it back after validation.

## Pre-migration validation

### 1. Validate all render paths

```sh
just gitops-validate
```

This renders the bootstrap paths, the cluster entrypoint, and all area paths with `kustomize build --enable-helm`.

### 2. Validate individual render output when debugging

```sh
just gitops-render infrastructure/sealed-secrets
just gitops-render infrastructure/argocd/install
just gitops-render infrastructure/argocd/bootstrap
just gitops-render clusters/k3s
```

### 3. Preview live-cluster diffs

These commands contact the cluster but do not apply changes:

```sh
kustomize build --enable-helm infrastructure/sealed-secrets | kubectl diff -f - || true
kustomize build --enable-helm infrastructure/argocd/install | kubectl diff -f - || true
kustomize build --enable-helm infrastructure/argocd/bootstrap | kubectl diff -f - || true
```

After Argo CD is installed, use Argo CD's UI or CLI diffs before syncing area Applications.

### 4. Record current live state

```sh
kubectl get pods -A
kubectl get pvc -A
kubectl get ingress -A
kubectl get sealedsecrets -A
helm list -A
```

Keep the output in local notes if you want a before/after comparison.

## Migration

### 1. Apply Sealed Secrets through Kustomize

This lets the Kustomize-rendered chart adopt or update the existing Sealed Secrets install.

```sh
kustomize build --enable-helm infrastructure/sealed-secrets | kubectl apply -f -
kubectl -n kube-system rollout status deploy/sealed-secrets-controller
```

Confirm existing sealed secrets can still decrypt:

```sh
kubectl get sealedsecrets -A
kubectl get secrets -A | grep -E 'tailscale|cloudflared|postgres' || true
```

### 2. Install Argo CD

```sh
kustomize build --enable-helm infrastructure/argocd/install | kubectl apply -f -
kubectl -n argocd rollout status deploy/argocd-server
kubectl -n argocd get pods
```

### 3. Apply Argo CD bootstrap resources

This applies the repository credential SealedSecret and the GitOps Root Application.

```sh
kustomize build --enable-helm infrastructure/argocd/bootstrap | kubectl apply -f -
```

Wait for the repository credential Secret to exist:

```sh
kubectl -n argocd get secret hemera-repo
```

### 4. Access Argo CD

Use port-forwarding during migration:

```sh
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Get the initial admin password if needed:

```sh
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

Log in with the CLI if desired:

```sh
argocd login localhost:8080 --username admin --password '<password>' --insecure
```

### 5. Sync the root Application manually

Sync `hemera-root` manually. Do not enable auto-sync or pruning.

```sh
argocd app get hemera-root
argocd app diff hemera-root || true
argocd app sync hemera-root
```

This creates the area Applications from `clusters/k3s/`.

### 6. Sync area Applications manually in wave order

Review diffs before each sync:

```sh
argocd app diff hemera-infrastructure || true
argocd app sync hemera-infrastructure

argocd app diff hemera-operators || true
argocd app sync hemera-operators

argocd app diff hemera-storage || true
argocd app sync hemera-storage

argocd app diff hemera-access || true
argocd app sync hemera-access

argocd app diff hemera-apps || true
argocd app sync hemera-apps
```

If a diff looks destructive, stop and fix the manifests before syncing that area.

## Post-migration

### 1. Confirm Argo CD owns the expected Applications

```sh
argocd app list
argocd app get hemera-root
argocd app get hemera-infrastructure
argocd app get hemera-operators
argocd app get hemera-storage
argocd app get hemera-access
argocd app get hemera-apps
```

### 2. Confirm cluster health

```sh
kubectl get pods -A
kubectl get pvc -A
kubectl get ingress -A
kubectl get storageclass
kubectl get crd clusters.postgresql.cnpg.io
```

### 3. Stop using Helmfile for migrated Cluster Resources

After Argo CD is managing a component, do not use Helmfile to upgrade that same component. Helmfile files may remain temporarily as references during the migration, but Argo CD is the intended owner after handoff.

### 4. Keep sync manual and pruning disabled

Do not enable automated sync or pruning until the operator has reviewed the first stable reconciliation cycle.

Suggested later order for enabling pruning, if desired:

1. `hemera-apps`
2. `hemera-access`
3. `hemera-operators`
4. `hemera-infrastructure`
5. `hemera-storage` last, if ever

### 5. Configure steady-state private access

Bootstrap access uses port-forwarding. Steady-state Argo CD access should be exposed only through Tailscale or another private internal path. Do not expose Argo CD publicly without a separate authentication decision.

## Validation checklist

### Repository validation

```sh
just gitops-validate
nix flake check --no-write-lock-file
```

### Bootstrap component validation

```sh
kustomize build --enable-helm infrastructure/sealed-secrets >/tmp/sealed-secrets.rendered.yaml
kustomize build --enable-helm infrastructure/argocd/install >/tmp/argocd-install.rendered.yaml
kustomize build --enable-helm infrastructure/argocd/bootstrap >/tmp/argocd-bootstrap.rendered.yaml
```

### Argo CD validation

```sh
kubectl -n argocd get pods
kubectl -n argocd get applications.argoproj.io
argocd app list
argocd app diff hemera-root || true
```

### Workload validation

```sh
kubectl get pods -A
kubectl get pvc -A
kubectl get ingress -A
kubectl -n longhorn-system get pods
kubectl -n cnpg-system get pods
kubectl -n tailscale get pods
kubectl -n cloudflared get pods
```

### Secret validation

```sh
kubectl -n argocd get secret hemera-repo
kubectl get sealedsecrets -A
kubectl get secrets -A | grep -E 'tailscale|cloudflared|postgres|hemera-repo' || true
```

## Rollback and pause strategy

Because initial sync is manual and pruning is disabled, the safest rollback is usually to stop syncing, fix the repository, and resync.

If Argo CD itself is unhealthy:

1. Stop syncing Applications.
2. Use `kubectl` to inspect `argocd` namespace resources.
3. Re-apply the Argo CD install path if needed:

   ```sh
   kustomize build --enable-helm infrastructure/argocd/install | kubectl apply -f -
   ```

4. Do not delete PVCs, namespaces, or application resources as part of rollback unless you explicitly intend data loss.

Deleting Argo CD `Application` objects should not delete managed resources unless pruning/finalizers have been enabled, but verify the object before deleting anything.
