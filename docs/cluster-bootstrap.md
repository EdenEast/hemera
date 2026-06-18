# Cluster Bootstrap

This runbook initializes a new Hemera Kubernetes cluster from an empty Proxmox topology to a usable k3s cluster. Run commands from the repository root unless a step says otherwise.

## Prerequisites

- Proxmox nodes are installed and reachable at `192.168.2.51`, `192.168.2.52`, and `192.168.2.53`.
- The operator workstation can SSH to each Proxmox node as `root` without relying on a local SSH alias.
- Nix flakes are available locally.
- A Proxmox API token is available, preferably from a password manager rather than committed files.
- The operator workstation public SSH key is available for First Boot Configuration.
- The Flux CLI is available for GitOps bootstrap.

Enter the development shell so `just`, `terraform`, `colmena`, `kubectl`, `helmfile`, and `kubeseal` are available:

```sh
nix develop
```

The development shell sets `KUBECONFIG` to `generated/kubeconfig`.

## 1. Prepare Proxmox

Enable Proxmox snippets on the storage used for cloud-init user data. Terraform uploads First Boot Configuration snippets over SSH.

```sh
for host in 192.168.2.51 192.168.2.52 192.168.2.53; do
  ssh root@$host 'pvesm set local --content backup,iso,vztmpl,snippets,import'
done
```

Confirm SSH works directly:

```sh
ssh-add -L
for host in 192.168.2.51 192.168.2.52 192.168.2.53; do
  ssh root@$host true
done
```

## 2. Register a NixOS cloud-init template

Build the NixOS Proxmox image, upload it to `node-01`, restore it as a VM, and convert that VM to a Proxmox template:

```sh
just template-register 9000 nixos-cloudinit-template-v1
```

Use versioned template IDs and names for replacements, for example `9001` and `nixos-cloudinit-template-v2`.

Only intentionally replace an existing template ID with:

```sh
HEMERA_TEMPLATE_REPLACE=1 just template-register 9000 nixos-cloudinit-template-v1
```

If the Proxmox host, storage, or bridge differs from the defaults, override the script environment variables documented by:

```sh
scripts/register-proxmox-template
```

## 3. Configure Terraform inputs

Create local Terraform variables:

```sh
cp terraform/proxmox/terraform.tfvars.example terraform/proxmox/terraform.tfvars
```

Fill in local values in `terraform/proxmox/terraform.tfvars`. At minimum set:

```hcl
proxmox_endpoint             = "https://192.168.2.51:8006/"
proxmox_snippet_datastore_id = "local"
proxmox_bridge               = "vmbr0"
template_source_node         = "node-01"
nixos_template_id            = 9000
admin_ssh_public_key         = "ssh-ed25519 ..."
```

Keep Proxmox credentials out of git. Prefer exporting the token from a password manager:

```sh
export TF_VAR_proxmox_api_token="$(op read 'op://Homelab/Proxmox Terraform/token')"
```

`admin_ssh_public_key` is only for first boot SSH reachability. Ongoing SSH access is declared in `nix/public_keys/` and applied by Colmena.

## 4. Create Cluster Node VMs

Review and apply the Terraform plan:

```sh
terraform init
terraform plan
terraform apply
```

The development shell wraps Terraform so these commands use `terraform/proxmox/` as the working directory.

Current Terraform topology:

| Cluster Node | Role | IP | VM ID |
| --- | --- | --- | --- |
| `k8s-cp-01` | Control Plane Node | `192.168.2.54` | `501` |
| `k8s-worker-01` | Worker Node | `192.168.2.55` | `511` |
| `k8s-cp-02` | Control Plane Node | `192.168.2.56` | `502` |
| `k8s-worker-02` | Worker Node | `192.168.2.57` | `512` |
| `k8s-cp-03` | Control Plane Node | `192.168.2.58` | `503` |
| `k8s-worker-03` | Worker Node | `192.168.2.59` | `513` |

After Terraform finishes, verify SSH reachability:

```sh
for host in 192.168.2.54 192.168.2.55 192.168.2.56 192.168.2.57 192.168.2.58 192.168.2.59; do
  ssh admin@$host true
done
```

## 5. Bootstrap k3s with Colmena

Apply the Control Plane Node first. This initializes k3s and writes a local kubeconfig to `generated/kubeconfig`:

```sh
just bootstrap-control-plane
```

Then join Worker Nodes. The script fetches the k3s node token from the Control Plane Node, installs it on each Worker Node, applies the worker NixOS configuration, and waits for each node to become ready:

```sh
just bootstrap-workers
```

Equivalent combined command:

```sh
just bootstrap-cluster
```

Validate the cluster:

```sh
kubectl get nodes -o wide
kubectl get pods -A
```

Refresh kubeconfig later with:

```sh
just kubeconfig
```

Useful overrides:

```sh
CONTROL_PLANE_IP=192.168.2.54 just kubeconfig
CONTROL_PLANE_SSH=admin@192.168.2.54 just bootstrap-workers
SSH_USER=admin just bootstrap-workers
```

## 6. Bootstrap Flux GitOps

Hemera uses Flux CD to reconcile Kubernetes resources from this repository. If rebuilding a cluster that must reuse existing sealed secrets, restore the Sealed Secrets private key before bootstrapping Flux. The private key backup is operator-managed and must not be committed to this repository.

After the cluster is reachable, bootstrap Flux against the Git remote for this repo:

```sh
scripts/bootstrap-flux
```

Flux creates `clusters/k3s/flux-system/` during bootstrap and then reconciles the cluster entrypoint in `clusters/k3s/`.

Reconciliation dependencies:

```text
infrastructure -> operators
infrastructure -> storage
infrastructure -> access
operators + storage + access -> apps
operators + storage + access -> monitoring
```

Validate Flux:

```sh
flux get kustomizations
flux get sources git
flux get sources helm -A
flux get helmreleases -A
kubectl get pods -A
```

See [`docs/flux-gitops.md`](flux-gitops.md) for the operating model.

### kube-vip

Hemera uses kube-vip for the Kubernetes API VIP at `192.168.2.50:6443`. Flux manages the kube-vip manifest from `access/kube-vip/`.

Validate:

```sh
kubectl -n kube-system get daemonset kube-vip-ds
kubectl -n kube-system get pods -l app.kubernetes.io/name=kube-vip -o wide
kubectl --server=https://192.168.2.50:6443 get nodes -o wide
```

If rebuilding from scratch and the VIP is not available yet, use a kubeconfig that points directly at a reachable Control Plane Node while bootstrapping Flux:

```sh
CONTROL_PLANE_IP=192.168.2.54 \
KUBE_API_ENDPOINT=https://192.168.2.54:6443 \
just kubeconfig
```

After kube-vip is healthy, refresh the normal VIP-based kubeconfig:

```sh
just kubeconfig
```

### Manual fallback

Existing Helmfile and raw manifest commands remain available as a temporary fallback during the Flux migration, but Flux should be the normal source of truth once bootstrap succeeds.

## Recovery notes

- Terraform owns Proxmox VM lifecycle only; it does not install k3s.
- Cloud-init is only First Boot Configuration and should not contain cluster secrets.
- Colmena is the Bootstrap Step that turns reachable Cluster Nodes into k3s members.
- The k3s join token is copied from the Control Plane Node during Worker Node bootstrap and is not stored in Terraform state or git.
- If `generated/kubeconfig` is missing or stale, rerun `just kubeconfig`.
- If a Worker Node partially joined, inspect it with `kubectl get node <name>` before rerunning `just bootstrap-workers`.
