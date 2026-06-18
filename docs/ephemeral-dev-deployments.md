# Ephemeral development deployments

Flux reconciles Hemera from git commits, not from the local working tree. To test uncommitted changes on the single cluster, deploy a temporary copy of an application into a separate development namespace with `kubectl apply -k`, test it, then delete it.

This workflow is for short-lived validation only. Flux remains the source of truth for normal production deployments.

## When to use this

Use an ephemeral development deployment when you need to test:

- local Kubernetes manifest changes before committing them;
- a new image, environment variable, probe, volume mount, or ingress rule;
- Longhorn PVC behavior with a fresh development volume;
- an app copy that should not mutate production resources.

Do not use this workflow for permanent deployments. If the result should stay, commit the final manifests and let Flux reconcile them.

## Safety rules

- Use a separate namespace, usually `<app>-dev`.
- Use a separate ingress hostname, usually `<app>-dev.hemera.local`.
- Do not apply local test manifests over the production namespace/name.
- Treat production PVCs and databases as off-limits unless intentionally testing a restore or migration.
- Be careful with cluster-scoped resources. Namespace isolation does not protect resources such as `ClusterRole`, `ClusterIssuer`, `StorageClass`, or CRDs.
- Remember that Flux will not prune resources that were created only from your local working tree.

## Create a local overlay

Keep ephemeral overlays outside the Flux reconciliation path. Good choices are `/tmp`, `.local/`, or another untracked local directory.

If using `.local/`, keep it out of git with either:

```sh
echo '.local/' >> .git/info/exclude
```

or by placing the overlay in `/tmp/hemera-dev/<app>` instead.

Example layout for testing the `send` app:

```text
.local/dev/send/
└── kustomization.yaml
```

Example `.local/dev/send/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../../apps/send

namespace: send-dev

commonLabels:
  hemera.dev/ephemeral: "true"
  hemera.dev/source-app: send

patches:
  - target:
      kind: Namespace
      name: send
    patch: |-
      - op: replace
        path: /metadata/name
        value: send-dev

  - target:
      kind: Ingress
      name: send
    patch: |-
      - op: replace
        path: /spec/rules/0/host
        value: send-dev.hemera.local
```

Most namespaced resources can keep their production object names because they live in the development namespace. For example, `Deployment/send`, `Service/send`, and `PersistentVolumeClaim/send-uploads` can exist in both `send` and `send-dev`.

## Add local test changes

Put test-only changes in the local overlay as patches. For example, to test a different image:

```yaml
patches:
  - target:
      kind: Deployment
      name: send
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/image
        value: registry.gitlab.com/timvisee/send:latest
```

If the change is intended to become permanent, make the final change in the real app manifests under `apps/` after the dev deployment passes testing.

## Use the Nix development environment

Run the commands from the repository's Nix development shell so the pinned `kubectl` is used:

```sh
nix develop --no-write-lock-file
```

If `direnv` is enabled for the repository, entering the directory also loads the same shell from `.envrc`.

`kubectl apply -k` works with the `kubectl` package in this shell; a separate `kustomize` binary is not required for this workflow. To verify local Kustomize support without touching the cluster:

```sh
nix develop --no-write-lock-file -c kubectl apply --dry-run=client -k apps/send -o name
```

## Validate before applying

Render the local overlay:

```sh
kubectl kustomize .local/dev/send
```

Ask the API server to validate it without persisting anything:

```sh
kubectl apply --dry-run=server -k .local/dev/send
```

Preview the difference between the local overlay and the live cluster:

```sh
kubectl diff -k .local/dev/send
```

## Deploy the local configuration

Apply the local overlay directly:

```sh
kubectl apply -k .local/dev/send
```

This bypasses Flux. It does not require committing or pushing.

Watch rollout status:

```sh
kubectl -n send-dev get pods
kubectl -n send-dev rollout status deploy/send
kubectl -n send-dev describe deploy/send
```

Check logs:

```sh
kubectl -n send-dev logs deploy/send --all-containers --tail=100
```

## Test the development ingress

The dev ingress must use a host that is different from production, such as `send-dev.hemera.local`.

Check that the ingress exists:

```sh
kubectl -n send-dev get ingress
kubectl -n send-dev describe ingress send
```

If local DNS already resolves `*.hemera.local`, test normally:

```sh
curl -I http://send-dev.hemera.local
```

If DNS does not resolve the dev hostname yet, find the ingress address and use `curl --resolve`:

```sh
kubectl -n send-dev get ingress send
curl --resolve send-dev.hemera.local:80:<INGRESS_ADDRESS> \
  -I http://send-dev.hemera.local
```

For HTTPS ingress, use port `443`:

```sh
curl --resolve send-dev.hemera.local:443:<INGRESS_ADDRESS> \
  -I https://send-dev.hemera.local
```

Also verify the service path behind ingress:

```sh
kubectl -n send-dev get svc,endpoints
kubectl -n send-dev port-forward svc/send 8080:80
curl -I http://127.0.0.1:8080
```

Adjust the forwarded service port if the service does not expose port `80`.

## Test development storage

Development deployments should normally use fresh development PVCs. Because the PVCs are namespaced, applying the app into `send-dev` creates independent PVCs such as `send-uploads` and `send-redis` in that namespace.

Check PVC binding:

```sh
kubectl -n send-dev get pvc
kubectl -n send-dev describe pvc send-uploads
```

Confirm the backing storage class:

```sh
kubectl -n send-dev get pvc -o wide
```

For Longhorn-backed PVCs, also check the Longhorn UI or Longhorn resources if needed:

```sh
kubectl -n longhorn-system get volumes.longhorn.io
```

Test that the application can write to the mounted volume. One option is to exec into the pod and write a temporary file to the mounted path:

```sh
POD=$(kubectl -n send-dev get pod -l app.kubernetes.io/name=send -o jsonpath='{.items[0].metadata.name}')
kubectl -n send-dev exec "$POD" -c send -- sh -c 'echo dev-storage-test > /uploads/.dev-storage-test && cat /uploads/.dev-storage-test'
```

Then restart the pod and confirm the file remains:

```sh
kubectl -n send-dev delete pod "$POD"
kubectl -n send-dev rollout status deploy/send
POD=$(kubectl -n send-dev get pod -l app.kubernetes.io/name=send -o jsonpath='{.items[0].metadata.name}')
kubectl -n send-dev exec "$POD" -c send -- cat /uploads/.dev-storage-test
```

Remove the test file before cleanup if desired:

```sh
kubectl -n send-dev exec "$POD" -c send -- rm -f /uploads/.dev-storage-test
```

## Secrets and databases

Some app copies may need secrets or database resources.

- Sealed Secrets are usually namespace-sensitive unless sealed with a broader scope. A production sealed secret may not decrypt in `<app>-dev`.
- Prefer creating a temporary development secret manually for the dev namespace.
- Prefer a separate development database or a restored copy, not the production database.
- If testing a CloudNativePG `Cluster`, make sure the dev copy has a different namespace and does not point at production PVCs or credentials.

Create a temporary secret when needed:

```sh
kubectl -n send-dev create secret generic example-dev-secret \
  --from-literal=username=dev \
  --from-literal=password=dev-password
```

If the secret is referenced by manifests, include a local overlay patch to use the development secret name.

## Cleanup

Delete everything created by the local overlay:

```sh
kubectl delete -k .local/dev/send
```

For a fully isolated namespace, deleting the namespace is often the simplest cleanup:

```sh
kubectl delete namespace send-dev
```

Wait until the namespace is gone:

```sh
kubectl get namespace send-dev --watch
```

Confirm no development resources remain:

```sh
kubectl get all,pvc,ingress -n send-dev
```

If the namespace no longer exists, that command should fail with `NotFound`.

For Longhorn storage, confirm development volumes were removed after the PVCs are deleted:

```sh
kubectl -n longhorn-system get volumes.longhorn.io | grep send-dev
```

No output means no matching Longhorn volume remains.

Finally, remove the local overlay if it is no longer useful:

```sh
rm -rf .local/dev/send
```

## Promotion path

After the dev deployment passes testing:

1. Copy only the intended permanent changes into the real manifests under `apps/`, `access/`, `monitoring/`, or the appropriate Flux-managed directory.
2. Validate the real Flux path locally:

   ```sh
   kubectl apply --dry-run=server -k apps/send
   kubectl diff -k apps/send
   ```

3. Commit and push the final change.
4. Let Flux reconcile it from git.

The ephemeral deployment proves the behavior, but the committed manifests remain the production source of truth.
