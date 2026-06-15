# Argo CD Bootstrap

This runbook describes how Hemera enters the GitOps Managed Phase with Argo CD. Run commands from the repository root after the Cluster Nodes and k3s are already bootstrapped.

For migrating the existing live cluster from the Manual Apply Phase, use `docs/argocd-migration.md`.

Argo CD starts with manual sync and pruning disabled. Do not make live changes from this runbook unless you intend to bootstrap or recover a cluster.

## Render model

Hemera renders GitOps Components with Kustomize, including Helm-backed components:

```sh
kustomize build --enable-helm <path> | kubectl apply -f -
```

Argo CD is configured with the matching `kustomize.buildOptions: --enable-helm` setting.

## Brand New Cluster

Use this path when the cluster has no previous Sealed Secrets key and no committed sealed credentials that must decrypt.

1. Install Sealed Secrets first:

   ```sh
   kustomize build --enable-helm infrastructure/sealed-secrets | kubectl apply -f -
   kubectl -n kube-system rollout status deploy/sealed-secrets-controller
   ```

2. Back up the newly generated Sealed Secrets private key outside git:

   ```sh
   kubectl -n kube-system get secret \
     -l sealedsecrets.bitnami.com/sealed-secrets-key \
     -o yaml > sealed-secrets-private-key.backup.yaml
   ```

3. Fetch the public certificate and commit it if it changed:

   ```sh
   kubeseal --fetch-cert > infrastructure/sealed-secrets/pub-cert.pem
   ```

4. Create a read-only deploy key for `EdenEast/hemera`, add the public key to the repository, and seal the private key as an Argo CD repository credential:

   ```sh
   cp infrastructure/argocd/bootstrap/repo-credential.secret.example.yaml /tmp/hemera-repo.secret.yaml
   # Edit /tmp/hemera-repo.secret.yaml with the private deploy key.
   kubeseal --format yaml \
     --cert infrastructure/sealed-secrets/pub-cert.pem \
     < /tmp/hemera-repo.secret.yaml \
     > infrastructure/argocd/bootstrap/repo-credential.sealed.yaml
   rm /tmp/hemera-repo.secret.yaml
   ```

5. Uncomment `repo-credential.sealed.yaml` in `infrastructure/argocd/bootstrap/kustomization.yaml`.

6. Install Argo CD:

   ```sh
   kustomize build --enable-helm infrastructure/argocd/install | kubectl apply -f -
   kubectl -n argocd rollout status deploy/argocd-server
   ```

7. Apply Argo CD bootstrap resources:

   ```sh
   kustomize build --enable-helm infrastructure/argocd/bootstrap | kubectl apply -f -
   ```

8. Access Argo CD during bootstrap with port-forwarding:

   ```sh
   kubectl -n argocd port-forward svc/argocd-server 8080:443
   ```

9. Log in and manually sync `hemera-root`, then sync area Applications in wave order: infrastructure, operators, storage, access, apps.

## Control Cluster Rebuild

Use this path when rebuilding the Self-Managed Cluster that runs Hemera's Argo CD instance.

1. Recreate Node Management and k3s with the normal cluster bootstrap runbook.
2. Install Sealed Secrets:

   ```sh
   kustomize build --enable-helm infrastructure/sealed-secrets | kubectl apply -f -
   kubectl -n kube-system rollout status deploy/sealed-secrets-controller
   ```

3. Restore the previous Sealed Secrets private key from secure storage:

   ```sh
   kubectl apply -f sealed-secrets-private-key.backup.yaml
   kubectl -n kube-system rollout restart deploy/sealed-secrets-controller
   kubectl -n kube-system rollout status deploy/sealed-secrets-controller
   ```

4. Install Argo CD and apply bootstrap resources:

   ```sh
   kustomize build --enable-helm infrastructure/argocd/install | kubectl apply -f -
   kubectl -n argocd rollout status deploy/argocd-server
   kustomize build --enable-helm infrastructure/argocd/bootstrap | kubectl apply -f -
   ```

5. Port-forward to Argo CD and manually sync `hemera-root`, then area Applications in wave order.

Only reseal all secrets with a new Sealed Secrets key if the old private key is lost or compromised.

## Managed Cluster Onboarding

Use this path when the existing Control Cluster should reconcile another Kubernetes cluster. See `docs/managed-cluster-onboarding.md` for the detailed model.

At a high level:

1. Build the new Managed Cluster with its own Node Management and k3s bootstrap.
2. Create a restricted Argo CD service account or kubeconfig for the Managed Cluster.
3. Store that credential as an Argo CD cluster credential Secret in the Control Cluster's `argocd` namespace.
4. Seal that credential with the Control Cluster Sealed Secrets certificate.
5. Add a sibling Cluster Entry Point under `clusters/` and an Argo CD Application that targets the Managed Cluster.
