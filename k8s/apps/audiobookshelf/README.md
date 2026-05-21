# Audiobookshelf

Audiobookshelf is deployed as a single-replica Kubernetes app.

## Storage design

Phase 1 uses Longhorn for application state:

- `/config` -> `audiobookshelf-config` Longhorn PVC
- `/metadata` -> `audiobookshelf-metadata` Longhorn PVC

The audiobook library is not mounted yet. Later, add a read-only TrueNAS NFS mount at:

- `/audiobooks` -> TrueNAS NFS export, read-only

## Networking

Audiobookshelf listens on container port `13378`.

Traffic flow:

```text
Browser
  -> Ingress: audiobookshelf.hemera.local
  -> Service: audiobookshelf port 80
  -> Pod: audiobookshelf port 13378
```

## Apply

```sh
export KUBECONFIG=$PWD/generated/kubeconfig
kubectl apply -f k8s/apps/audiobookshelf/namespace.yaml
kubectl apply -f k8s/apps/audiobookshelf/pvc.yaml
kubectl apply -f k8s/apps/audiobookshelf/deployment.yaml
kubectl apply -f k8s/apps/audiobookshelf/service.yaml
kubectl apply -f k8s/apps/audiobookshelf/ingress.yaml
```

Or apply the whole directory:

```sh
kubectl apply -f k8s/apps/audiobookshelf/
```

## Validate

```sh
kubectl -n audiobookshelf get pvc
kubectl -n audiobookshelf get pods
kubectl -n audiobookshelf get svc,ingress
```

The PVCs should become `Bound`, and the pod should become `Running`.

## Local DNS

The hostname `audiobookshelf.hemera.local` must resolve to the k3s ingress/load balancer address from your browser machine.
