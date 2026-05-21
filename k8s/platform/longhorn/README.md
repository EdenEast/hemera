# Longhorn

Longhorn provides Kubernetes-native replicated block storage for Hemera application state such as config, databases, and metadata.

Media libraries should stay on TrueNAS and be mounted separately over NFS.

## Layering

- NixOS prepares each Cluster Node with iSCSI and NFS client tools.
- Helmfile installs Longhorn into Kubernetes.
- Applications request Longhorn storage with `storageClassName: longhorn`.

## Apply

Make sure the kubeconfig points at the Hemera cluster:

```sh
export KUBECONFIG=$PWD/generated/kubeconfig
kubectl get nodes
```

Apply Longhorn:

```sh
helmfile -f k8s/platform/longhorn/helmfile.yaml apply
```

Validate:

```sh
kubectl -n longhorn-system get pods
kubectl get storageclass
```

A successful install should create a `longhorn` StorageClass.

## Backups

Longhorn replicas protect against node/disk failure. They are not backups.

After the TrueNAS backup dataset/export exists, set `defaultSettings.backupTarget` in `values.yaml`, for example:

```yaml
defaultSettings:
  backupTarget: "nfs://192.168.2.X:/mnt/tank/backups/longhorn"
```

Then re-apply Helmfile.
