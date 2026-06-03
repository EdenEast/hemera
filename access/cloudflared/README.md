# Cloudflared

Cloudflared connects Hemera services to Cloudflare Tunnel.

This deployment uses a dashboard-managed tunnel token. Public hostnames and service routing are configured in Cloudflare Zero Trust, not in Kubernetes manifests.

## Create a tunnel

In Cloudflare Zero Trust:

1. Open **Networks → Tunnels**.
2. Create a tunnel, for example `hemera`.
3. Choose a connector method that gives a tunnel token.
4. Copy the tunnel token.

## Seal the tunnel token

Create a temporary Secret from the example:

```sh
cp access/cloudflared/tunnel-token.secret.example.yaml access/cloudflared/tunnel-token.secret.yaml
```

Edit `access/cloudflared/tunnel-token.secret.yaml` and replace `CHANGE_ME` with the Cloudflare tunnel token.

Seal it:

```sh
kubeseal --from-file access/cloudflared/tunnel-token.secret.yaml \
  --format yaml > access/cloudflared/tunnel-token.sealed.yaml
rm access/cloudflared/tunnel-token.secret.yaml
```

The sealed Secret must be named `cloudflared-tunnel-token` in the `cloudflared` namespace and contain the key `token`.

## Apply

```sh
export KUBECONFIG=$PWD/generated/kubeconfig
kubectl apply -k access/cloudflared
```

## Validate

```sh
kubectl -n cloudflared get pods
kubectl -n cloudflared logs deploy/cloudflared
```

## Audiobookshelf example

In the Cloudflare Tunnel public hostname settings:

```text
Hostname: audiobookshelf.edeneast.xyz
Service:  http://audiobookshelf.audiobookshelf.svc.cluster.local:80
```

Cloudflare should create or manage the DNS record for the hostname.

Breakdown of example service URL `http://audiobookshelf.audiobookshelf.svc.cluster.local:80`:

| Component         | Explanation                                                                                                         |
| :--------         | :----------                                                                                                         |
| https://          | Audiobookshelf’s Kubernetes service is plain HTTP internally. TLS is handled by Cloudflare at the edge/tunnel layer |
| audiobookshelf    | The Kubernetes Service name from `kind: Service` + `metadata.name: audiobookshelf`                                  |
| audiobookshelf    | The namespace of the service `metadata.namespace: audiobookshelf`                                                   |
| svc.cluster.local | The full Kubernetes cluster DNS suffix                                                                              |
| :80               | The Service port `kind: Service` + `spec.ports.port: 80`                                                            |

## Access control

Cloudflare Tunnel can expose services publicly. If a service should not be public, add a Cloudflare Access policy for the hostname.
