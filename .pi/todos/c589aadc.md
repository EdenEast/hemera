{
"id": "c589aadc",
"title": "Complete per-Cluster Node NixOS host configs",
"tags": [
"ready-for-agent"
],
"status": "closed",
"created_at": "2026-05-20T16:31:39.200Z"
}

## Parent

TODO-e9b3507c

## What to build

Make each Initial Setup Cluster Node host configuration evaluate as a concrete NixOS configuration with hostname, role, and placeholder static networking ready to confirm later.

## Acceptance criteria

- [x] `k8s-cp-01` is configured as the k3s server Cluster Node.
- [x] `k8s-worker-01` and `k8s-worker-02` are configured as k3s agent Cluster Nodes.
- [x] Static networking placeholders are represented declaratively and clearly marked for confirmation before deployment.

## Completed

- Added declarative placeholder static networking for all three Cluster Nodes.
- Preserved control-plane and worker role module imports.
