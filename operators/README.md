# Operators

This directory contains cluster-wide Kubernetes operators.

Operators are platform components that extend Kubernetes with custom resources and controllers. Hemera installs operators centrally, then keeps the application-owned resources they manage under each application directory.

For database requirements, ADR 0002 defines the ownership model:

- operator lifecycle: `operators/`
- application database instances: `apps/<app>/`

This keeps shared controllers centralized while making each application's state requirements visible beside the application manifests.

## Current operators

- `cloudnativepg/`: PostgreSQL operator used for app-owned PostgreSQL clusters.

## Future operators

Add another operator here only when Hemera needs a shared controller for multiple applications or when an app-local chart/manifest is not sufficient.

Do not place application database clusters in this directory. For example, a PostgreSQL `Cluster` for Immich belongs in `apps/immich/`, not `operators/cloudnativepg/`.
