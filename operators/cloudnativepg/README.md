# CloudNativePG

CloudNativePG is Hemera's standard PostgreSQL operator.

Per ADR 0002, this directory owns the operator lifecycle only. Application PostgreSQL clusters belong in `apps/<app>/` because database version, extensions, storage size, credentials, and recovery behavior are application requirements.

## Install or upgrade

```sh
export KUBECONFIG=$PWD/generated/kubeconfig

Important PostgreSQL clusters should gain database-aware backups before the application is treated as critical state.
