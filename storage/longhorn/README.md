# Longhorn

Longhorn provides replicated Kubernetes block storage for application state.

## Install or upgrade

This directory uses Helmfile, not Flux.

```sh
export KUBECONFIG=$PWD/generated/kubeconfig
helmfile -f storage/longhorn/helmfile.yaml apply
```


## Values

Hemera uses two replicas during the single-Thor phase. This saves capacity while keeping node-level resilience inside the running cluster; it does not protect against Thor or its SSD failing.

The default StorageClass is disabled:

```yaml
persistence:
  defaultClass: false
```

Applications should request Longhorn explicitly with `storageClassName: longhorn`.

## Optional frontend access

After Longhorn is installed, expose the existing frontend service if needed. These manifests assume the referenced ingress classes exist (`traefik` for LAN and `tailscale` for tailnet):

```sh
kubectl apply -f storage/longhorn/ingress.yaml
```

Validate:

```sh
kubectl -n longhorn-system get pods
kubectl -n longhorn-system get svc longhorn-frontend
kubectl get storageclass longhorn -o yaml
```

Keep the Longhorn frontend private to the LAN or tailnet.
