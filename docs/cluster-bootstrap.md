# Cluster Bootstrap

This runbook initializes a new Hemera Kubernetes cluster from an empty Proxmox topology to a usable k3s cluster. Run commands from the repository root unless a step says otherwise.

## Prerequisites

- Thor is installed with Proxmox and reachable at `192.168.2.80`.
- The operator workstation can SSH to Thor as `root` without relying on a local SSH alias.
- Nix flakes are available locally.
- A Proxmox API token is available, preferably from a password manager rather than committed files.
- The operator workstation public SSH key is available for First Boot Configuration.

Enter the development shell so `just`, `terraform`, `colmena`, `kubectl`, `helmfile`, and `kubeseal` are available:

```sh
nix develop
```

The development shell sets `KUBECONFIG` to `generated/kubeconfig`.

## 1. Prepare Proxmox

Enable Proxmox snippets on the storage used for cloud-init user data. Terraform uploads First Boot Configuration snippets over SSH.

```sh
ssh root@192.168.2.80 'pvesm set local --content backup,iso,vztmpl,snippets,import'
```

Confirm SSH works directly:

```sh
ssh-add -L
ssh root@192.168.2.80 true
```

## 2. Register a NixOS cloud-init template

Build the NixOS Proxmox image, upload it to Thor, restore it as a VM, and convert that VM to a Proxmox template:

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
proxmox_endpoint      = "https://192.168.2.80:8006/"
proxmox_node_name     = "pve"
proxmox_node_address  = "192.168.2.80"
proxmox_datastore_id  = "local-lvm"
nixos_template_id     = 9000
admin_ssh_public_key  = "ssh-ed25519 ..."
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
| `k8s-cp-01` | Control Plane Node | `192.168.2.81` | `501` |
| `k8s-worker-01` | Worker Node | `192.168.2.82` | `511` |
| `k8s-worker-02` | Worker Node | `192.168.2.83` | `512` |

After Terraform finishes, verify SSH reachability:

```sh
ssh admin@192.168.2.81 true
ssh admin@192.168.2.82 true
ssh admin@192.168.2.83 true
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
CONTROL_PLANE_IP=192.168.2.81 just kubeconfig
CONTROL_PLANE_SSH=admin@192.168.2.81 just bootstrap-workers
SSH_USER=admin just bootstrap-workers
```

## 6. Install platform components

Hemera is currently in a Manual Apply Phase: manifests are organized as future GitOps inputs, but the operator applies them manually.

Install components in dependency order.

### Sealed Secrets

```sh
helmfile -f infrastructure/sealed-secrets/helmfile.yaml apply
kubectl -n kube-system rollout status deploy/sealed-secrets-controller
```

If rebuilding a cluster that must decrypt existing committed `SealedSecret` manifests, restore the backed-up Sealed Secrets private key from secure storage and restart the controller:

```sh
kubectl apply -f sealed-secrets-private-key.backup.yaml
kubectl -n kube-system rollout restart deploy/sealed-secrets-controller
kubectl -n kube-system rollout status deploy/sealed-secrets-controller
```

Do not commit the private key backup. If no backup exists, fetch the new public certificate and reseal each secret before applying workloads:

```sh
kubeseal --fetch-cert > infrastructure/sealed-secrets/pub-cert.pem
```

### Longhorn Storage

```sh
helmfile -f storage/longhorn/helmfile.yaml apply
kubectl -n longhorn-system get pods
kubectl get storageclass longhorn
```

Apply the optional private Longhorn frontend ingress only after the relevant ingress classes exist:

```sh
kubectl apply -f storage/longhorn/ingress.yaml
```

### CloudNativePG

```sh
helmfile -f operators/cloudnativepg/helmfile.yaml apply
kubectl get crd clusters.postgresql.cnpg.io
```

### Access components

Tailscale operator:

```sh
kubectl apply -f access/tailscale/operator-oauth.sealed.yaml
helmfile -f access/tailscale/helmfile.yaml apply
```

Cloudflared:

```sh
kubectl apply -k access/cloudflared
kubectl -n cloudflared rollout status deploy/cloudflared
```

## 7. Apply applications

Apply application manifests after platform dependencies are ready.

Example order:

```sh
kubectl apply -f apps/audiobookshelf/namespace.yaml
kubectl apply -f apps/audiobookshelf/

kubectl apply -f apps/forgejo/namespace.yaml
kubectl apply -f apps/forgejo/
```

Validate workloads:

```sh
kubectl get pods -A
kubectl get pvc -A
kubectl get ingress -A
```

## Recovery notes

- Terraform owns Proxmox VM lifecycle only; it does not install k3s.
- Cloud-init is only First Boot Configuration and should not contain cluster secrets.
- Colmena is the Bootstrap Step that turns reachable Cluster Nodes into k3s members.
- The k3s join token is copied from the Control Plane Node during Worker Node bootstrap and is not stored in Terraform state or git.
- If `generated/kubeconfig` is missing or stale, rerun `just kubeconfig`.
- If a Worker Node partially joined, inspect it with `kubectl get node <name>` before rerunning `just bootstrap-workers`.
