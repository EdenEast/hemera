## Rules you must follow

Do not make any modifications to services running in the cluster unless specifically told to.

Before making changes to any files, show the proposed changes and ask for validation

## Repository Structure

```
access/            # Ingress controllers, Authentik, ExternalDNS
apps/              # Application HelmReleases (jellyfin, n8n, ollama, etc.)
clusters/          # Flux GitOps definitions (k3s, lab)
infrastructure/    # Core components (MetalLB, cert-manager, sealed-secrets)
monitoring/        # Prometheus, Grafana, Loki, Alloy
nix/               # Nix modules
operators/         # CloudNativePG, MariaDB, Redis operators
scripts/           # Automated scripts
storage/           # Longhorn, NFS provisioner
terraform/         # Cluster machine provisioning
tools/             # Utility tools
```

## Cluster Info

- Primary cluster: `clusters/k3s/`
- Main namespace: various per-app
- Storage class: `longhorn`
- Ingress: Envoy Gateway (gateway.networking.k8s.io/v1 HTTPRoute)
