# Tailscale Kubernetes Operator

This installs the Tailscale Kubernetes Operator so selected Kubernetes services can be exposed privately on the tailnet.

## Why use the operator?

The operator creates Tailscale proxy pods for specific Kubernetes `Ingress` or `Service` resources. This avoids exposing the whole LAN through a subnet router when only one app needs tailnet access.

## Prerequisites

Create an OAuth client in the Tailscale admin console:

1. Go to **Settings → OAuth clients**.
2. Create an OAuth client.
3. Grant scopes needed by the Kubernetes operator, including device auth key creation.
4. Save the generated client id and client secret.

Do not commit those credentials to this repository in plaintext. Store them in the SOPS-encrypted `operator-oauth.secret.sops.yaml` file.

## Edit the OAuth secret

From the repo root:

```sh
sops k8s/platform/tailscale/operator-oauth.secret.sops.yaml
```

Replace the placeholder values:

```yaml
stringData:
  client_id: CHANGEME_TAILSCALE_OAUTH_CLIENT_ID
  client_secret: CHANGEME_TAILSCALE_OAUTH_CLIENT_SECRET
```

SOPS will write the file back encrypted.

## Install

From the repo root:

```sh
export KUBECONFIG=$PWD/generated/kubeconfig

kubectl create namespace tailscale --dry-run=client -o yaml | kubectl apply -f -
sops --decrypt k8s/platform/tailscale/operator-oauth.secret.sops.yaml | kubectl apply -f -
helmfile -f k8s/platform/tailscale/helmfile.yaml apply
```

The Tailscale chart expects a pre-created Secret named `operator-oauth` with `client_id` and `client_secret` keys. This is why the secret is applied before Helmfile.

## Validate

```sh
kubectl -n tailscale get pods
kubectl get ingressclass
```

You should see the Tailscale operator running and an ingress class named `tailscale`.

## Exposing apps

Apps opt in by creating an additional ingress with:

```yaml
spec:
  ingressClassName: tailscale
```

For Audiobookshelf, see `k8s/apps/audiobookshelf/tailscale-ingress.yaml`.
