# Use app-owned databases with central operators

Hemera will manage database requirements with centralized database operators and application-owned database instances. Operators such as CloudNativePG live under `operators/`, while each application's PostgreSQL, Redis, or Valkey resources live under that application's directory in `apps/<app>/`.

For PostgreSQL, Hemera will use CloudNativePG per application by default. For Redis-compatible requirements, Hemera will prefer app-owned Valkey or Redis resources. Bundled chart Redis/Valkey is acceptable when the service is disposable cache or clearly scoped to one application.

## Context

Applications in Hemera increasingly need durable database services. Immich is the current example: it uses CloudNativePG for PostgreSQL, stores database state on Longhorn, and uses Valkey from the application chart.

Hemera already separates concerns by repository area:

- `operators/` contains cluster-wide operators.
- `apps/` contains application manifests and Helmfile inputs.
- `storage/` contains Longhorn, the explicit storage class for application state.
- `infrastructure/` contains shared platform services such as Sealed Secrets.

Database ownership should follow that structure. The operator lifecycle is platform-owned, but the database instance is application-owned because its version, extensions, size, credentials, and recovery needs are part of the application's requirements.

## Decision

- Install and upgrade database operators centrally under `operators/`.
- Define application database instances under `apps/<app>/`.
- Use CloudNativePG as the default PostgreSQL mechanism.
- Create one PostgreSQL cluster per important application by default.
- Store durable database state on Longhorn with `storageClass: longhorn` or `storageClassName: longhorn`.
- Store database credentials as committed Sealed Secrets.
- Prefer Valkey naming where supported, while treating Redis and Valkey as Redis-compatible services.
- Use bundled chart Redis/Valkey only for disposable cache or simple app-local needs.
- Add database-aware backups for important PostgreSQL clusters before relying on them as critical state.

A typical application layout should look like:

```text
apps/example-app/
  namespace.yaml
  postgres-user.sealed.yaml
  postgres-cluster.yaml
  values.yaml
  helmfile.yaml
  kustomization.yaml
```

If an application needs Redis or Valkey, the relevant manifest or Helm values should also live in that same app directory.

## Considered Options

- App-owned databases with central operators: matches the current Immich pattern, keeps ownership clear, supports app-specific PostgreSQL versions and extensions, and limits blast radius.
- One shared PostgreSQL cluster and one shared Redis/Valkey service: uses fewer resources, but couples app upgrades, increases blast radius, and makes extension/version conflicts more likely.
- Application chart bundled databases: easy to deploy, but backup, restore, upgrade, and operational behavior vary by chart. Acceptable for cache, less suitable for primary durable databases.
- External databases outside Kubernetes: can survive Kubernetes rebuilds and may be easy to snapshot, but moves important Application State outside Hemera's Kubernetes model and makes lifecycle management less visible in the repository.

## Consequences

- Application directories become the source of truth for application database requirements.
- Multiple database instances may consume more memory and storage than shared services.
- Application failures and database upgrades are better isolated.
- PostgreSQL extensions and custom images can be handled per application, as Immich requires.
- Backup policy must be applied consistently across application-owned database resources.
- Shared database services remain possible later, but should be introduced only when resource pressure outweighs isolation and upgrade simplicity.
