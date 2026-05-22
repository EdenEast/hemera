# Longhorn Storage Validation

Use this checklist after changing Hemera's Longhorn storage layout. It validates the full path from Proxmox VM disks, through NixOS Cluster Node mounts, into Longhorn and Kubernetes PVCs.

TrueNAS-backed Longhorn backups are intentionally deferred. Backup creation and restore validation are not part of this checklist yet. Until a real backup target and restore drill exist, Longhorn data is not protected from accidental deletion or loss of Thor's physical SSD.

## 1. Terraform validation

Run from the repository root:

```sh
terraform -chdir=terraform/proxmox fmt -check
terraform -chdir=terraform/proxmox validate
terraform -chdir=terraform/proxmox plan -input=false
```

Confirm the plan shows the intended Cluster Node disk layout:

- `k8s-cp-01`
  - root disk: 40GB on `virtio0`
  - no Longhorn data disk
- `k8s-worker-01`
  - root disk: 60GB on `virtio0`
  - Longhorn data disk: 250GB on `virtio1`
  - data disk serial: `longhorn-data`
- `k8s-worker-02`
  - root disk: 60GB on `virtio0`
  - Longhorn data disk: 250GB on `virtio1`
  - data disk serial: `longhorn-data`

Confirm the total VM disk allocation is about 660GB on Thor's 1TB SSD, leaving headroom for Proxmox, templates, logs, snapshots, and recovery work.

## 2. NixOS evaluation and deployment

Evaluate all Cluster Node configurations:

```sh
scripts/check-nixos-eval
```

After applying Terraform, deploy NixOS configuration to the worker Cluster Nodes:

```sh
scripts/deploy-node k8s-worker-01
scripts/deploy-node k8s-worker-02
```

The Longhorn data disk module formats an empty data disk as ext4 on first activation and mounts it at `/var/lib/longhorn`. It leaves an existing filesystem unchanged.

## 3. Worker mount verification

Confirm the stable disk path exists on both worker Cluster Nodes:

```sh
ssh root@192.168.2.82 ls -l /dev/disk/by-id/virtio-longhorn-data
ssh root@192.168.2.83 ls -l /dev/disk/by-id/virtio-longhorn-data
```

Confirm `/var/lib/longhorn` is mounted from the dedicated data disk:

```sh
ssh root@192.168.2.82 findmnt /var/lib/longhorn
ssh root@192.168.2.83 findmnt /var/lib/longhorn
```

Confirm capacity is approximately 250GB on each worker:

```sh
ssh root@192.168.2.82 df -h /var/lib/longhorn
ssh root@192.168.2.83 df -h /var/lib/longhorn
```

## 4. Longhorn health and StorageClass verification

Make sure the kubeconfig points at the Hemera cluster:

```sh
export KUBECONFIG=$PWD/generated/kubeconfig
kubectl get nodes -o wide
```

Apply or re-apply Longhorn:

```sh
helmfile -f k8s/platform/longhorn/helmfile.yaml apply
```

Validate Longhorn system health:

```sh
kubectl -n longhorn-system get pods
kubectl -n longhorn-system get nodes.longhorn.io
kubectl -n longhorn-system get disks.longhorn.io
```

Validate the StorageClass and replica count:

```sh
kubectl get storageclass
kubectl get storageclass longhorn -o yaml
```

Confirm the Longhorn defaults align with the single-Thor phase:

- default replica count: 2
- default StorageClass replica count: 2
- backup target: empty/deferred

## 5. Longhorn PVC smoke test

Create a test namespace and PVC:

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

The PVC should become `Bound`.

Mount the PVC in a temporary pod:

```sh
kubectl -n longhorn-smoke-test apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: longhorn-smoke-test
spec:
  restartPolicy: Never
  containers:
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c", "echo hemera-longhorn-ok > /data/check.txt && cat /data/check.txt && sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: longhorn-smoke-test
EOF
kubectl -n longhorn-smoke-test wait --for=condition=Ready pod/longhorn-smoke-test --timeout=120s
kubectl -n longhorn-smoke-test logs longhorn-smoke-test
```

The pod logs should include:

```text
hemera-longhorn-ok
```

Cleanup:

```sh
kubectl delete namespace longhorn-smoke-test
```

## 6. Audiobookshelf PVC validation

Apply Audiobookshelf manifests:

```sh
kubectl apply -f k8s/apps/audiobookshelf/
```

Validate Longhorn-backed application state PVCs:

```sh
kubectl -n audiobookshelf get pvc
kubectl -n audiobookshelf describe pvc audiobookshelf-config
kubectl -n audiobookshelf describe pvc audiobookshelf-metadata
kubectl -n audiobookshelf get pods
```

Confirm:

- `audiobookshelf-config` uses the `longhorn` StorageClass and is `Bound`.
- `audiobookshelf-metadata` uses the `longhorn` StorageClass and is `Bound`.
- the Audiobookshelf pod reaches `Running`.
- no large audiobook media PVC is created in Longhorn.

## 7. Explicitly deferred backup validation

Skip Longhorn backup and restore validation for now. TrueNAS-backed Longhorn backups are not configured in the current storage slice.

Do not consider important data safe until a future backup task configures an external Longhorn backup target and validates restore behavior.
