# App-owned database templates

These templates implement ADR 0002: database operators are managed centrally, while application database instances are owned by the application directory.

Use these files when adding an application that needs PostgreSQL, Redis, or Valkey.

## PostgreSQL

Hemera uses CloudNativePG for PostgreSQL.

1. Install or upgrade the operator:

   ```sh
   helmfile -f operators/cloudnativepg/helmfile.yaml apply
   ```

2. Copy the PostgreSQL template into the application directory:

   ```sh
   cp apps/_templates/database/postgres-cluster.yaml apps/<app>/postgres-cluster.yaml
   ```

3. Replace the placeholders:

   - `APP_NAME`
   - `APP_NAMESPACE`
   - `APP_DATABASE`
   - `APP_DATABASE_OWNER`
   - `APP_POSTGRES_SECRET`
   - storage size
   - PostgreSQL image/version
   - resource requests/limits

4. Create a local Secret from `postgres-user.secret.example.yaml`, seal it, then remove the unsealed Secret file:

   ```sh
   kubeseal --from-file apps/<app>/postgres-user.secret.yaml \
     --format yaml > apps/<app>/postgres-user.sealed.yaml
   rm apps/<app>/postgres-user.secret.yaml
   ```

5. Add the sealed secret and cluster manifest to the app's `kustomization.yaml`.

## Redis / Valkey

Use Redis-compatible services based on the application's state requirements:

- Disposable cache: bundled chart Redis/Valkey is acceptable, with no or minimal persistence.
- Queue/session/state: app-owned Redis/Valkey with Longhorn persistence.
- Many low-risk apps under memory pressure: consider a shared service later, but document the blast radius first.

Prefer the `Valkey` name where a chart supports it. Use `Redis` when the chart or application uses that name.

## Baseline application layout

```text
apps/<app>/
  namespace.yaml
  postgres-user.sealed.yaml
  postgres-cluster.yaml
  values.yaml
  helmfile.yaml
  kustomization.yaml
```

If the app needs Valkey or Redis, keep the manifest or values snippet in the same application directory.
