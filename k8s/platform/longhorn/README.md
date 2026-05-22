# Longhorn

Longhorn provides Kubernetes-native replicated block storage for Hemera application state such as config, databases, and metadata.

Media libraries should stay on TrueNAS and be mounted separately over NFS. Longhorn is for application state, not large media libraries.

## Current Thor storage model

Hemera's current Initial Setup runs all Cluster Nodes as NixOS VMs on Thor:

```text
Thor 1TB physical SSD
  -> Proxmox datastore
    -> Cluster Node virtual disks
      -> NixOS filesystems inside each VM
        -> Longhorn storage path on each Cluster Node
          -> Longhorn volumes / Kubernetes PVCs
```

Longhorn can only use storage that is visible inside the Cluster Nodes. It does not automatically use all free space on Thor's physical SSD. If the Cluster Node VMs only have small virtual disks, Longhorn capacity is limited by those virtual disks.

The single-Thor storage budget is:

| Cluster Node | Root Disk | Longhorn Data Disk | Longhorn Storage Role |
| ------------ | --------: | -----------------: | --------------------- |
| k8s-cp-01 | 40GB | none | control-plane only |
| k8s-worker-01 | 60GB | 250GB | Longhorn storage node |
| k8s-worker-02 | 60GB | 250GB | Longhorn storage node |

This allocates about 660GB of VM disk capacity on Thor's 1TB SSD and leaves the remaining space for Proxmox, templates, logs, snapshots, and operational recovery headroom.

The worker data disks are attached with the Proxmox disk serial `longhorn-data`. NixOS mounts them through the stable `/dev/disk/by-id/virtio-longhorn-data` path at `/var/lib/longhorn`. On first activation with an empty disk, NixOS formats the disk as ext4 and labels it `longhorn-data`.

The current topology has one physical failure domain: Thor and its single SSD. Longhorn replicas can help with node-level problems inside the running cluster, such as a VM being unavailable or a Longhorn replica failing. They do not make the Initial Setup highly available and they do not protect against Thor's SSD failing.

## Data safety rules

Recreating a VM object is not the same as deleting storage. Treat these operations differently:

- Recreating a Cluster Node VM can preserve data only if the relevant Longhorn data disks, PVCs, and Longhorn volumes are preserved and reattached correctly.
- Deleting a PVC may delete the backing Longhorn volume depending on the StorageClass reclaim behavior.
- Deleting a namespace that contains PVCs can also delete those PVCs.
- Deleting a Longhorn volume deletes the stored data unless it has been backed up elsewhere.
- Losing Thor's physical SSD loses the Proxmox datastore, VM disks, and Longhorn replicas stored on that SSD.

Before destructive operations, inspect the StorageClass and affected PVCs:

```sh
kubectl get storageclass longhorn -o yaml
kubectl get pvc --all-namespaces
```

## Replica count

Hemera uses two Longhorn replicas during the single-Thor phase:

```yaml
defaultSettings:
  defaultReplicaCount: 2

persistence:
  defaultClassReplicaCount: 2
```

This is intentional. Three replicas fit a three-node cluster shape, but all three replicas would still live on the same physical SSD today. Two replicas reduce storage overhead while keeping useful resilience against a single Cluster Node or replica being unavailable.

Requested PVC size is multiplied by the replica count. For example:

```text
10Gi PVC with 2 replicas -> about 20Gi raw Longhorn storage
20Gi PVC with 2 replicas -> about 40Gi raw Longhorn storage
```

Snapshots, filesystem overhead, and application growth require additional headroom.

## Layering

- Terraform owns Proxmox VM lifecycle: VM creation, CPU, memory, virtual disks, and network attachment.
- NixOS owns Cluster Node state: filesystems, mounts, host tools, iSCSI, and NFS client tooling.
- Helmfile installs and configures Longhorn inside Kubernetes.
- Applications request Longhorn storage with `storageClassName: longhorn`.

## Validation checklist

For the full end-to-end storage validation flow, see `docs/longhorn-storage-validation.md`.

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

Validate the worker mounts before applying Longhorn:

```sh
ssh root@192.168.2.82 findmnt /var/lib/longhorn
ssh root@192.168.2.83 findmnt /var/lib/longhorn
ssh root@192.168.2.82 ls -l /dev/disk/by-id/virtio-longhorn-data
ssh root@192.168.2.83 ls -l /dev/disk/by-id/virtio-longhorn-data
```

Then validate Longhorn:

```sh
kubectl -n longhorn-system get pods
kubectl get storageclass
kubectl get storageclass longhorn -o yaml
```

A successful install should create a `longhorn` StorageClass using the configured replica count.

## PVC smoke test

Create a small test PVC using Longhorn:

```sh
kubectl create namespace longhorn-smoke-test --dry-run=client -o yaml | kubectl apply -f -
kubectl -n longhorn-smoke-test apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-smoke-test
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 128Mi
EOF
kubectl -n longhorn-smoke-test get pvc longhorn-smoke-test
```

The PVC should become `Bound`. Cleanup:

```sh
kubectl delete namespace longhorn-smoke-test
```

## Backups

Longhorn replicas are not backups.

TrueNAS-backed Longhorn backups are intentionally deferred for now. Until a backup target and restore drill are configured, do not treat Longhorn data as protected from accidental deletion or physical Thor disk loss.

When backup work is resumed later, configure a real Longhorn backup target outside Thor, such as a TrueNAS NFS export, and validate both backup creation and restore before storing important data.
