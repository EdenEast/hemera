# Audiobookshelf

Audiobookshelf is deployed as a single-replica Kubernetes app.

## Storage design

Audiobookshelf uses Longhorn only for application state:

- `/config` -> `audiobookshelf-config` Longhorn PVC
- `/metadata` -> `audiobookshelf-metadata` Longhorn PVC

Large audiobook media should not be stored in Longhorn. Longhorn replicas multiply storage use and, while all Cluster Nodes run on Thor, do not protect media from loss of Thor's physical SSD.

The audiobook library is mounted from TrueNAS over NFS:

- `/audiobooks` -> `192.168.2.116:/mnt/Volume/Files/Media/Audiobooks`, read-only

The media mount is read-only from the Audiobookshelf container so the service can index and serve the library without becoming the writer of record for the media files.

The pod runs as the same numeric identity used by the TrueNAS NFS service account:

- user: `audiobookshelf`, UID `3001`
- group: `media`, GID `3000`

Keeping the Kubernetes process UID/GID aligned with the TrueNAS NFS identity avoids relying on root-specific NFS mapping behavior.

TrueNAS-backed Longhorn backups are not configured yet. Do not treat the current Longhorn PVCs as protected from accidental deletion or physical Thor disk loss.

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
kubectl apply -f k8s/apps/audiobookshelf/namespaces.yaml
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
kubectl -n audiobookshelf describe pvc audiobookshelf-config
kubectl -n audiobookshelf describe pvc audiobookshelf-metadata
kubectl -n audiobookshelf get pods
kubectl -n audiobookshelf get svc,ingress
```

The `audiobookshelf-config` and `audiobookshelf-metadata` PVCs should use the `longhorn` StorageClass and become `Bound`. The pod should become `Running` with `/config` and `/metadata` mounted from those PVCs, plus `/audiobooks` mounted read-only from TrueNAS NFS. No large media PVC should be created in Longhorn.

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
