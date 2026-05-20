# Use k3s for the initial Kubernetes cluster

Hemera uses k3s for the Initial Setup Kubernetes cluster instead of kubeadm, Talos, or RKE2. k3s provides a real Kubernetes environment with lower operational and hardware overhead, which fits the initial single-host Proxmox deployment on `thor` while leaving room to revisit the distribution later.

## Consequences

- The Initial Setup can rely on k3s defaults such as local-path storage, Traefik, and ServiceLB.
- The cluster is optimized for homelab learning and constrained hardware, not production-grade high availability.
- A future migration to another Kubernetes distribution may require replacing k3s-specific defaults.
