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

LAN traffic flow:

```text
Browser
  -> Ingress: audiobookshelf.hemera.local
  -> Service: audiobookshelf port 80
  -> Pod: audiobookshelf port 13378
```

Tailnet traffic flow:

```text
Tailnet client
  -> Tailscale Ingress: audiobookshelf
  -> Service: audiobookshelf port 80
  -> Pod: audiobookshelf port 13378
```

The Tailscale ingress requires the Tailscale Kubernetes Operator from
`k8s/platform/tailscale/`.

## Apply

```sh
export KUBECONFIG=$PWD/generated/kubeconfig
kubectl apply -f k8s/apps/audiobookshelf/namespace.yaml
kubectl apply -f k8s/apps/audiobookshelf/pvc.yaml
kubectl apply -f k8s/apps/audiobookshelf/deployment.yaml
kubectl apply -f k8s/apps/audiobookshelf/service.yaml
kubectl apply -f k8s/apps/audiobookshelf/ingress.yaml
kubectl apply -f k8s/apps/audiobookshelf/tailscale-ingress.yaml
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

## Tailnet access

Install the Tailscale Kubernetes Operator first. Its OAuth credentials are stored in the SOPS-encrypted secret at `k8s/platform/tailscale/operator-oauth.secret.sops.yaml`:

```sh
export KUBECONFIG=$PWD/generated/kubeconfig
kubectl create namespace tailscale --dry-run=client -o yaml | kubectl apply -f -
sops --decrypt k8s/platform/tailscale/operator-oauth.secret.sops.yaml | kubectl apply -f -
helmfile -f k8s/platform/tailscale/helmfile.yaml.gotmpl apply
```

Then apply the Audiobookshelf Tailscale ingress:

```sh
kubectl apply -f k8s/apps/audiobookshelf/tailscale-ingress.yaml
kubectl -n audiobookshelf get ingress audiobookshelf-tailscale
```

Once the operator reconciles the ingress, Audiobookshelf should be reachable from devices in your tailnet at the Tailscale-provided HTTPS hostname for `audiobookshelf`.
