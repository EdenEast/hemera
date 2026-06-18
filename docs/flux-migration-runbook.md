# Flux Migration Runbook

Use this runbook to move Hemera from manual Kubernetes applies and Helmfile-driven installs to Flux-managed cluster reconciliation.

## 0. Preconditions

Run from the repository root inside the development shell:

```sh
nix develop
```

Confirm the cluster is reachable:

```sh
kubectl get nodes -o wide
kubectl get pods -A
```

Confirm the Flux CLI is available:

```sh
flux --version
```

## 1. Review and commit the GitOps manifests

Flux reconciles from git, not from the local working tree. Before bootstrap, review, commit, and push the Flux layout:

```sh
git status --short
git diff
```

Expected new/changed areas include:

```text
clusters/k3s/
access/**/kustomization.yaml
apps/**/kustomization.yaml
infrastructure/**/kustomization.yaml
operators/**/kustomization.yaml
storage/**/kustomization.yaml
monitoring/kustomization.yaml
scripts/bootstrap-flux
docs/flux-gitops.md
```

Commit and push when ready:

```sh
git add clusters access apps infrastructure operators storage monitoring scripts/bootstrap-flux docs/flux-gitops.md docs/flux-migration-runbook.md docs/adr/0003-flux-for-kubernetes-reconciliation.md CONTEXT.md docs/cluster-bootstrap.md
git commit -m "feat: add flux gitops reconciliation"
git push origin main
```

## 2. Validate Kustomize entrypoints locally

These should all render successfully before Flux sees them:

```sh
for path in apps access infrastructure operators storage monitoring; do
  kubectl kustomize "$path" >/dev/null
done
```

## 3. Confirm current Helm releases for in-place adoption

Flux should adopt the current releases instead of reinstalling them:

```sh
helm list -A
```

Expected release names and namespaces:

```text
sealed-secrets-controller  kube-system       sealed-secrets-2.18.6
cloudnative-pg             cnpg-system       cloudnative-pg-0.28.2
longhorn                   longhorn-system   longhorn-1.11.2
tailscale-operator         tailscale         tailscale-operator-1.98.4
```

If the live versions differ, update the matching Flux `release.yaml` before bootstrapping.

## 4. Restore Sealed Secrets key when rebuilding

If this is a brand-new cluster that must decrypt existing committed `SealedSecret` manifests, restore the Sealed Secrets private key before bootstrapping Flux:

```sh
kubectl apply -f sealed-secrets-private-key.backup.yaml
```

Do not commit the private key backup.

If this is not a rebuild, skip this step.

## 5. Bootstrap Flux

Run:

```sh
scripts/bootstrap-flux
```

This installs Flux and creates `clusters/k3s/flux-system/` for this repository. Commit and push the generated Flux system files if `flux bootstrap` did not already do so:

```sh
git status --short
git add clusters/k3s/flux-system
git commit -m "chore: bootstrap flux"
git push origin main
```

## 6. Watch reconciliation

Check Flux sources and Kustomizations:

```sh
flux get sources git
flux get kustomizations
```

Expected Kustomizations:

```text
flux-system
infrastructure
operators
storage
access
apps
monitoring
```

Reconciliation dependencies are:

```text
infrastructure -> operators
infrastructure -> storage
infrastructure -> access
operators + storage + access -> apps
operators + storage + access -> monitoring
```

## 7. Validate Helm adoption

Confirm Flux sees Helm sources and releases:

```sh
flux get sources helm -A
flux get helmreleases -A
```

Confirm Helm release names stayed the same:

```sh
helm list -A
```

Confirm key controllers are healthy:

```sh
kubectl -n kube-system rollout status deploy/sealed-secrets-controller
kubectl -n cnpg-system get pods
kubectl -n longhorn-system get pods
kubectl -n tailscale get pods
```

## 8. Validate workloads and access resources

```sh
kubectl get namespaces
kubectl get pods -A
kubectl get pvc -A
kubectl get ingress -A
```

Validate kube-vip:

```sh
kubectl -n kube-system get daemonset kube-vip-ds
kubectl -n kube-system get pods -l app.kubernetes.io/name=kube-vip -o wide
kubectl --server=https://192.168.2.50:6443 get nodes -o wide
```

## 9. Stop using Helmfile as the normal path

After Flux is healthy, make future cluster changes in git and let Flux reconcile them.

Helmfile files may remain as temporary fallback or recovery documentation, but do not use Helmfile for routine upgrades once the matching `HelmRelease` is Flux-managed.

## 10. Common recovery commands

Force Flux to fetch the latest git revision:

```sh
flux reconcile source git flux-system -n flux-system
```

Force an area to reconcile:

```sh
flux reconcile kustomization infrastructure -n flux-system
flux reconcile kustomization operators -n flux-system
flux reconcile kustomization storage -n flux-system
flux reconcile kustomization access -n flux-system
flux reconcile kustomization apps -n flux-system
flux reconcile kustomization monitoring -n flux-system
```

Inspect failures:

```sh
flux get kustomizations
flux logs --level=error --all-namespaces
kubectl -n flux-system get pods
kubectl -n flux-system logs deploy/source-controller
kubectl -n flux-system logs deploy/kustomize-controller
kubectl -n flux-system logs deploy/helm-controller
```

Suspend a broken area temporarily:

```sh
flux suspend kustomization apps -n flux-system
```

Resume it after fixing git:

```sh
flux resume kustomization apps -n flux-system
flux reconcile kustomization apps -n flux-system
```
