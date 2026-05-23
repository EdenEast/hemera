# Immich

Immich is deployed as a single-instance photo management app with separate PostgreSQL, Valkey, server, and machine-learning workloads.

## Storage design

Immich uses Longhorn only for application state and cache:

- PostgreSQL data -> `immich-postgres` Longhorn PVC
- Machine-learning model cache -> `immich-machine-learning-cache` Longhorn PVC

Large photo/video uploads should not be stored in Longhorn. The upload library is mounted from TrueNAS over NFS:

- `/usr/src/app/upload` -> `192.168.2.116:/mnt/Volume/Files/Media/Photos/Immich`, read-write

Create that TrueNAS dataset/path before applying this app, and make sure the Immich container can write to it. TrueNAS-backed Longhorn backups are not configured yet. Do not treat the current Longhorn PVCs as protected from accidental deletion or physical Thor disk loss.

## Networking

Immich listens on container port `2283`.

LAN traffic flow:

```text
Browser
  -> Ingress: immich.hemera.local
  -> Service: immich-server port 80
  -> Pod: immich-server port 2283
```

Tailnet traffic flow:

```text
Tailnet client
  -> Tailscale Ingress: immich
  -> Service: immich-server port 80
  -> Pod: immich-server port 2283
```

The Tailscale ingress requires the Tailscale Kubernetes Operator from `k8s/platform/tailscale/`.

## Apply

Before the first apply, replace the placeholder PostgreSQL password in `secret.yaml`.

```sh
export KUBECONFIG=$PWD/generated/kubeconfig
kubectl apply -f k8s/apps/immich/namespaces.yaml
kubectl apply -f k8s/apps/immich/secret.yaml
kubectl apply -f k8s/apps/immich/configmap.yaml
kubectl apply -f k8s/apps/immich/pvc.yaml
kubectl apply -f k8s/apps/immich/deployment.yaml
kubectl apply -f k8s/apps/immich/service.yaml
kubectl apply -f k8s/apps/immich/ingress.yaml
kubectl apply -f k8s/apps/immich/tailscale-ingress.yaml
```

Or apply the whole directory:

```sh
kubectl apply -f k8s/apps/immich/
```

## Validate

```sh
kubectl -n immich get pvc
kubectl -n immich get pods
kubectl -n immich get svc,ingress
kubectl -n immich logs deploy/immich-server
```

The `immich-postgres` and `immich-machine-learning-cache` PVCs should use the `longhorn` StorageClass and become `Bound`. The server pod should become `Running` with `/usr/src/app/upload` mounted read-write from TrueNAS NFS.

## Local DNS

The hostname `immich.hemera.local` must resolve to the k3s ingress/load balancer address from your browser machine.
