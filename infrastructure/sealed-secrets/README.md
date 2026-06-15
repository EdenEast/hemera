# Sealed Secrets

Sealed Secrets encrypts Kubernetes Secrets so the encrypted `SealedSecret` manifests can be committed to git.

## Install or upgrade

Sealed Secrets is rendered with Kustomize and installed first during Argo CD bootstrap:

```sh
kustomize build --enable-helm infrastructure/sealed-secrets | kubectl apply -f -
```

Validate:

```sh
kubectl -n kube-system rollout status deploy/sealed-secrets-controller
kubectl -n kube-system get pods -l app.kubernetes.io/name=sealed-secrets
```

After GitOps Handoff, Argo CD owns this component.

## Seal a secret

Create a normal Secret manifest locally and pipe it to `kubeseal`:

```sh
kubectl -n tailscale create secret generic operator-oauth \
  --from-literal=client_id="$TS_OAUTH_CLIENT_ID" \
  --from-literal=client_secret="$TS_OAUTH_CLIENT_SECRET" \
  --dry-run=client -o yaml |
kubeseal --format yaml > access/tailscale/operator-oauth.sealed.yaml
```

or create a temp secret file to then be sealed

```yaml
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: operator-oauth
  namespace: tailscale
stringData:
  client_id: "<client-id>"
  client_secret: "<client-secret>"
```

```sh
kubeseal --format yaml < secrets.yaml > access/tailscale/operator-oauth.sealed.yaml
rm secrets.yaml # dont forget to remove the temp secrets file
```

Apply the sealed secret before installing the workload that needs the decrypted Secret:

```sh
kubectl apply -f access/tailscale/operator-oauth.sealed.yaml
```

By default, sealed secrets are bound to the Secret name and namespace.

## Public certificate

Optional: fetch the public certificate used by `kubeseal`:

```sh
kubeseal --fetch-cert > infrastructure/sealed-secrets/pub-cert.pem
```

The public certificate is safe to commit.

## Private key backup

Back up the controller private key outside the repository. Without it, committed sealed secrets cannot be decrypted after a cluster rebuild.

```sh
kubectl -n kube-system get secret \
  -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o yaml > sealed-secrets-private-key.backup.yaml
```

Store that backup in a password manager or another secure location. Do not commit it.

## Decrypt Sealed secret locally

If you have the backup private key you can use it to decrypt a sealed secret if you lost a password for example to
connect to a database.

```sh
kubeseal --recovery-unseal \
    --recovery-private-key sealed-secrets-private-key.backup.yaml \
    < apps/<name>/postgres-user.sealed.yaml \
    -o yaml
```
