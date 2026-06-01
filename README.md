# Hemera

Hemera is a homelab Kubernetes platform running on personally owned hardware.  This repository organizes all
configuration, scripts, and infrastructure components for my homelab K3s clusterenvironment.

[Hemera](https://en.wikipedia.org/wiki/Hemera)  is the goddess of day and is the daughter of [Nyx](https://en.wikipedia.org/wiki/Nyx)
the goddess of night which is also my [nixos](https://github.com/edeneast/nyx) system configuration so it is fitting.

Pronounced: `heh - MEH - rah`

## Initial Cluster Bootstrap

These steps bootstrap a new Hemera Kubernetes cluster on the Proxmox host.
They assume Thor is already installed with Proxmox and reachable at
`192.168.2.80`.

### 1. Prepare Proxmox

Enable snippets on the storage used for cloud-init user-data. Terraform uploads
cloud-init snippets over SSH.

```sh
ssh root@192.168.2.80 'pvesm set local --content backup,iso,vztmpl,snippets,import'
```

Confirm SSH works without relying on `~/.ssh/config` aliases:

```sh
ssh-add -L
ssh root@192.168.2.80 true
```

### 2. Register the NixOS cloud-init template

Build the NixOS Proxmox image, upload it to Proxmox, restore it as a VM, and
convert it to a Proxmox template:

```sh
just template-register 9000 nixos-cloudinit-template-v1
```

Use a new versioned template ID/name for future replacements. To intentionally
replace an existing template ID:

```sh
HEMERA_TEMPLATE_REPLACE=1 just template-register 9000 nixos-cloudinit-template-v1
```

### 3. Configure Terraform inputs

Copy the example vars and fill in local values:

```sh
cp terraform/proxmox/terraform.tfvars.example terraform/proxmox/terraform.tfvars
```

`terraform.tfvars` is local-only. Keep Proxmox API tokens out of git. If using a
password manager, prefer exporting the token instead:

```sh
export TF_VAR_proxmox_api_token="$(op read 'op://Homelab/Proxmox Terraform/token')"
```

Set at least:

```hcl
proxmox_endpoint      = "https://192.168.2.80:8006/"
proxmox_node_name     = "pve"
proxmox_node_address  = "192.168.2.80"
proxmox_datastore_id  = "local-lvm"
nixos_template_id     = 9000
admin_ssh_public_key  = "ssh-ed25519 ..."
```

`admin_ssh_public_key` is the operator workstation/user public key used for
first boot SSH access. Ongoing SSH access is declared under `nix/public_keys/`
and applied by Colmena.

### 4. Create the Cluster Node VMs

Review the Terraform plan before applying. This creates/replaces Proxmox VMs for
the target topology.

```sh
just tf-init
just tf-plan
just tf-apply
```

### 5. Bootstrap k3s with Colmena

Apply the Control Plane Node first, fetch kubeconfig, then join Worker Nodes:

```sh
just bootstrap-control-plane
just bootstrap-workers
```

Validate the cluster:

```sh
kubectl --kubeconfig generated/kubeconfig get nodes -o wide
```

## Future Goals

This is something to review in the future but all of these services (Kubernetes, terraform, etc...) use yaml as their
format and are not very reproducible. Finding all the places where I can incorporate `nix` would be a useful endeavour.

Some useful links for later

- https://kubenix.org/
- https://github.com/Lillecarl/nix-csi
- https://github.com/Lillecarl/easykubenix
- https://nixidy.dev/
