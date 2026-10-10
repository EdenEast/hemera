# ntfy

Manifests for a private ntfy server at `https://ntfy.cerberus-tilapia.ts.net`.
This directory is included in `apps/kustomization.yaml` for Flux reconciliation once the
changes reach the Git branch watched by the cluster.

## Deployment shape

One non-root replica runs `binwiederhier/ntfy:v2.29.0` with a 1Gi Longhorn volume for SQLite
authentication and message cache. Messages are retained for 24 hours. Updates use `Recreate`
to avoid overlapping instances accessing the databases; this causes a short interruption.

The ClusterIP Service listens on port 80 and forwards to container port 8080. Tailscale
Ingress uses the existing `ingress-proxies` ProxyGroup for HTTPS access. Cluster publishers
can use `http://ntfy.ntfy.svc.cluster.local`.

Anonymous topic access and signup are disabled. The Deployment requires a Secret named
`ntfy-auth` with a `users` key containing a comma-separated list of
`username:bcrypt-password-hash:role` entries. Without it, the container will not start.
The example provisions one administrator; administrators have access to all topics.

Attachments, browser background push, and Alertmanager integration are outside this
configuration. Android delivery uses a direct connection to this server; no iOS upstream
relay or Firebase configuration is enabled.

## Administrator credentials

The initial administrator is `eden`. The generated password is stored locally in
`generated/ntfy-admin.json`, which Git ignores, with file permissions `0600`.
Transfer it to your password manager. `auth.sealed.yaml` contains the encrypted password
hash, not the plaintext password.

The Secret was sealed using `infrastructure/sealed-secrets/pub-cert.pem`. The cluster's
current certificate is newer, but its controller still accepts this Secret. Validation
with `kubeseal --validate` and live Secret decryption both passed during deployment.
For a different cluster, validate the Secret against that cluster before deploying.

## Android setup

1. Connect the phone to Hemera's Tailscale network.
2. Install the ntfy Android app from Google Play or F-Droid and allow notifications.
3. Add the server `https://ntfy.cerberus-tilapia.ts.net` under the app's user settings,
   with username `eden` and the generated password.
4. Subscribe to `hemera-test` using that server, then publish a test message.
5. Keep background delivery enabled and allow background operation for ntfy and Tailscale.
   Verify delivery with the phone locked and on mobile data.

Self-hosted subscriptions use ntfy's foreground service for instant delivery. The phone
must remain connected to Tailscale to reach the server. See the
[Android subscription documentation](https://docs.ntfy.sh/subscribe/phone/).

## Prepare credentials without deploying

Generate a password hash with the matching ntfy CLI:

```sh
ntfy user hash
```

Copy `auth.secret.example.yaml` to a private temporary directory outside the repository.
Replace `REPLACE_WITH_BCRYPT_HASH` with the generated hash. Keep literal `$` characters
in the hash; Kubernetes does not need Docker Compose's `$$` escaping.

Seal the temporary Secret using the repository's public certificate, without accessing
the cluster:

```sh
kubeseal --cert infrastructure/sealed-secrets/pub-cert.pem \
  --from-file /path/to/private/auth.secret.yaml \
  --format yaml > apps/ntfy/auth.sealed.yaml
```

Remove the plaintext temporary file. Confirm the certificate matches the intended cluster.
`auth.sealed.yaml` is already included in this directory's Kustomization.
The Secret name and namespace must remain `ntfy-auth` and `ntfy`.

The example Secret is excluded from Kustomization. Never replace its placeholder with
real credentials in the repository.

## Local validation

These commands render and validate manifests without contacting Kubernetes:

```sh
kustomize build apps/ntfy
kustomize build apps/ntfy | kubeconform -strict -summary -ignore-missing-schemas
```

The SealedSecret is a custom resource whose schema must be supplied separately for strict
validation; the command above skips schemas it cannot find.

## Deployment and verification

ntfy was deployed directly with `kubectl apply -k apps/ntfy` on October 9, 2026
(America/Toronto). Its replica is ready, the Longhorn PVC is bound, and Tailscale ingress
advertises `ntfy.cerberus-tilapia.ts.net`.

The parent app Kustomization includes ntfy locally. Flux will manage it once these changes
reach the watched Git branch. The existing app dependencies cover storage and access.

Live checks passed for HTTPS certificate validation, anonymous read/write denial,
administrator authentication, publishing, cached subscription, and live stream delivery.
A cached message survived a Deployment restart. Android notification delivery was also
validated on the user's device.

MagicDNS returns the service's IPv4 and IPv6 addresses. Thor's system resolver intermittently
returns negative answers because its global DNS configuration also sends the tailnet
domain to public resolvers. HTTPS verification used the service address with hostname
certificate validation where needed. This host DNS configuration was left unchanged.

After deployment, verify unauthorized requests cannot read or publish to a test topic,
authenticated publishing and subscription work, and cached messages survive a restart.
Test locked-phone delivery through Tailscale before relying on it for alerts.

ntfy reads configuration and provisioned users at startup. After changing the ConfigMap
or credential Secret, restart the Deployment during an authorized maintenance window.
Back up the data PVC to preserve messages and any accounts or tokens created through ntfy.
