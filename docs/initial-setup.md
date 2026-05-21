# Initial Setup

## Purpose

The Initial Setup establishes Hemera as a usable homelab Kubernetes platform on personally owned hardware. It should be practical for running local services, while also demonstrating DevOps-relevant infrastructure practices.

## Scope

Initial Setup includes:

- Installing and configuring Proxmox on `thor`.
- Creating a reusable NixOS VM template in Proxmox.
- Using Terraform to clone Kubernetes node VMs from that template.
- Using NixOS configurations deployed with `nixos-rebuild --target-host` to configure each node.
- Running a k3s Kubernetes cluster with one control-plane node and two worker nodes.
- Validating basic cluster storage and service exposure.

## Non-goals

The following are intentionally deferred:

- Highly available Kubernetes control plane.
- Multi-physical-node cluster topology.
- TrueNAS-backed dynamic Kubernetes storage.
- Monitoring and alerting stack.
- GitOps deployment with Argo CD or Flux.
- Colmena-based multi-host NixOS deployment.
- Cilium or other advanced Kubernetes networking stack.

## Architecture

Hemera starts as a single-physical-host Kubernetes lab. The physical desktop `thor` runs Proxmox. Proxmox hosts multiple NixOS virtual machines, each acting as a Kubernetes node. Terraform owns VM infrastructure creation, while NixOS owns operating-system and Kubernetes node configuration.

```text
+---------------------------------------------------+
| thor                                              |
| Proxmox                                           |
|                                                   |
|  +-------------+  +-------------+  +-------------+|
|  | k8s-cp-01   |  | worker-01   |  | worker-02   ||
|  | NixOS       |  | NixOS       |  | NixOS       ||
|  | k3s server  |  | k3s agent   |  | k3s agent   ||
|  +-------------+  +-------------+  +-------------+|
+---------------------------------------------------+
```

## Tool Responsibilities

| Tool                          | Responsibility                                                                                  |
| ----------------------------- | ----------------------------------------------------------------------------------------------- |
| Proxmox                       | Virtualization host on `thor`                                                                   |
| Terraform                     | Proxmox VM lifecycle using the `bpg/proxmox` provider: clone template, CPU, memory, disks, NICs |
| NixOS                         | Declarative node configuration: users, SSH, networking, k3s services                            |
| `nixos-rebuild --target-host` | Apply NixOS host configurations remotely                                                        |
| sops-nix                      | Manage encrypted NixOS secrets, including the k3s cluster token                                 |
| k3s                           | Lightweight Kubernetes distribution                                                             |
| Traefik / ServiceLB           | Initial k3s default ingress and service exposure                                                |
| local-path provisioner        | Initial Kubernetes persistent volume support                                                    |

Terraform should not install k3s or manage in-cluster Kubernetes resources. NixOS should own node state after the VM exists.

Terraform state records the infrastructure objects Terraform manages, including VM IDs, configured CPU and memory, disk definitions, network settings, and provider metadata. It may contain sensitive values depending on provider configuration, so state files must not be committed to git. For Initial Setup, Terraform state is local and gitignored, with manual backup to TrueNAS.

## Target Topology

| Hostname        | Role              | vCPU | RAM | Disk | Placeholder IP |
| --------------- | ----------------- | ---: | --: | ---: | -------------- |
| `k8s-cp-01`     | k3s control plane |    2 | 3GB | 40GB | `192.168.2.81` |
| `k8s-worker-01` | k3s worker        |    2 | 3GB | 60GB | `192.168.2.82` |
| `k8s-worker-02` | k3s worker        |    2 | 3GB | 60GB | `192.168.2.83` |

This topology is intentionally not highly available because all nodes initially run on one physical host.

## Network Assumptions

Confirmed Initial Setup network values:

```text
Proxmox host address: 192.168.2.80/24
LAN CIDR: 192.168.2.0/24
Gateway: 192.168.2.1
DNS: 192.168.2.1
Hemera static range: 192.168.2.80-192.168.2.99
Proxmox bridge: vmbr0
```

Static IP addresses are configured in NixOS, not Terraform. Terraform attaches VM NICs to the correct Proxmox bridge.

## Repository Layout

```text
docs/
  initial-setup.md
  nixos-proxmox-template.md

k8s/
  smoke-test/

terraform/
  proxmox/
    main.tf
    variables.tf
    outputs.tf
    terraform.tfvars.example

flake.nix

nix/
  hosts/
    k8s-cp-01/
      configuration.nix
    k8s-worker-01/
      configuration.nix
    k8s-worker-02/
      configuration.nix
  modules/
    common.nix
    k3s-server.nix
    k3s-agent.nix
    secrets.nix
  secrets/
    k3s.yaml

scripts/
  check-nixos-eval
  deploy-node
  deploy-cluster
  get-kubeconfig
  lib/cluster-nodes.sh

apps/
  helmfile.yaml   # later, not required for Initial Setup
```

## Setup Plan

### Work that can be completed before Proxmox

These repository tasks do not require Thor to run Proxmox yet:

- Define Terraform code for the expected Cluster Node topology.
- Keep Terraform variable examples and outputs current.
- Evaluate NixOS Node Configuration with `scripts/check-nixos-eval`.
- Prepare deployment and kubeconfig scripts around placeholder Cluster Node IPs.
- Prepare `sops-nix` scaffolding without real secret material.
- Prepare Kubernetes smoke-test manifests under `k8s/smoke-test/`.
- Document NixOS template creation and identity-safety expectations.

### Work that requires Proxmox on Thor

These tasks must wait until Thor has a live Proxmox install:

- Confirm Proxmox API endpoint, node name, bridge, datastore, and management IP.
- Create the Terraform API token.
- Import or build the reusable NixOS Proxmox VM template.
- Run Terraform plan/apply against the Proxmox API.
- Boot cloned Cluster Nodes and collect their unique SSH host keys for `sops-nix` recipients.
- Apply Node Configuration with `nixos-rebuild --target-host`.
- Validate the live k3s cluster, storage, and service exposure.

### Phase 1: Prepare Proxmox

1. Install Proxmox on `thor`.
2. Confirm network bridge name, storage pool name, and management IP.
3. Create a Terraform API token for Proxmox.
4. Record required values in `terraform/proxmox/terraform.tfvars`.

Values to confirm:

```text
Proxmox API endpoint: https://192.168.2.80:8006/
Proxmox node name: pve
Proxmox storage pool: local-lvm for VM disks, local for images/templates
Proxmox bridge: vmbr0
Terraform token ID: stored in local terraform.tfvars only
Terraform token secret: stored outside git
```

### Phase 2: Create NixOS VM Template

1. Prefer building the template from Nix with `nixos-generators`; see `docs/nixos-proxmox-template.md`.
2. If that is not feasible, import an official NixOS cloud image and convert it to a Proxmox template.
3. Configure shared baseline features:
   - SSH enabled.
   - admin user with SSH key.
   - QEMU guest agent.
   - Nix flakes enabled if the repo uses flakes.
   - Basic debugging tools.
4. Record the template name or ID for Terraform.

Template should contain only common baseline configuration. Hostname, static IP, and k3s role are per-node configuration.

The template must not clone machine identity into cluster nodes. SSH host keys and machine identity must be unique per cloned VM. During implementation, validate that cloned nodes do not share SSH host keys or `/etc/machine-id`.

### Phase 3: Provision Cluster Nodes with Terraform

1. Initialize Terraform:

   ```sh
   cd terraform/proxmox
   terraform init
   ```

2. Check formatting and validate the module:

   ```sh
   terraform fmt -check
   terraform validate
   ```

3. Preview VM creation:

   ```sh
   terraform plan
   ```

4. Apply infrastructure:

   ```sh
   terraform apply
   ```

5. Export outputs for scripts if useful:

   ```sh
   terraform output -json > ../../generated/terraform-outputs.json
   ```

Terraform should create three VMs from the NixOS template with the target CPU, memory, disk, and NIC configuration.

### Phase 4: Apply NixOS Node Configuration

First evaluate the Cluster Node configurations without contacting Proxmox or live VMs:

```sh
scripts/check-nixos-eval
```

Then use repo scripts around `nixos-rebuild --target-host`.

Example shape:

```sh
scripts/deploy-node k8s-cp-01
scripts/deploy-node k8s-worker-01
scripts/deploy-node k8s-worker-02
```

Underlying command shape:

```sh
nixos-rebuild switch \
  --flake .#k8s-cp-01 \
  --target-host root@192.168.2.81
```

The control-plane node should enable the k3s server role. Worker nodes should enable the k3s agent role and join the control-plane node.

The k3s cluster token should be generated once as a strong shared secret and managed with `sops-nix`. The encrypted secret may be committed to git, but decrypted secret material must not be committed. NixOS exposes the `k3s/token` secret to k3s at runtime at `/run/secrets/k3s-token`.

`sops-nix` should use one admin age key plus one age key per NixOS host. The admin key allows editing and recovery. Host keys allow each cluster node to decrypt the secrets it needs during activation.

Host age identities should be derived from each node's SSH host key. The NixOS VM template must not contain pre-generated SSH host keys; each cloned VM must generate unique SSH host keys on first boot.

Secret scaffolding that can be prepared before Proxmox is installed:

- Commit the `sops-nix` module wiring that declares the `k3s/token` secret and its runtime path.
- Commit `.sops.yaml` with placeholder recipients so the intended recipient model is visible.
- Commit only a placeholder `nix/secrets/k3s.yaml`; it must not contain a plaintext token.
- Keep age private keys, decrypted secret files, and local secret scratch files out of git.

Secret work that must wait until real Cluster Nodes exist:

1. Generate or identify the admin age public key and replace the admin placeholder in `.sops.yaml`.
2. Boot each cloned Cluster Node once so it generates a unique `/etc/ssh/ssh_host_ed25519_key`.
3. Convert each host SSH public key to an age recipient, for example with `ssh-to-age`, and replace the host placeholders in `.sops.yaml`.
4. Generate one strong k3s token, encrypt it with `sops`, and replace the placeholder `nix/secrets/k3s.yaml` with real encrypted content.
5. Confirm no plaintext token, age private key, or decrypted secret file is present in git status before committing.

### Phase 5: Validate Kubernetes

1. Retrieve kubeconfig from the control-plane node:

   ```sh
   scripts/get-kubeconfig
   ```

2. Confirm all nodes are ready:

   ```sh
   kubectl get nodes -o wide
   ```

3. Apply the prepared smoke-test manifests:

   ```sh
   kubectl apply -f k8s/smoke-test/namespace.yaml
   kubectl apply -f k8s/smoke-test/pvc.yaml
   kubectl apply -f k8s/smoke-test/app.yaml
   kubectl apply -f k8s/smoke-test/ingress.yaml
   ```

4. Confirm local-path storage can provision a PVC.
5. Confirm the sample app runs.
6. Expose the sample app through k3s default Traefik/ServiceLB.
7. Confirm the sample app is reachable from the LAN.

## Operational Safety Checks

Before committing repository changes:

- `terraform.tfvars`, Terraform state files, generated Terraform outputs, local kubeconfigs, decrypted SOPS files, plaintext secret scratch files, and age private keys must stay out of git.
- Encrypted secret files under `nix/secrets/` may be committed only when they contain SOPS-encrypted values, not plaintext token material.
- The local Terraform state for Initial Setup should be backed up manually to TrueNAS after successful infrastructure changes.

After cloning Cluster Nodes from the NixOS template, validate identity uniqueness before using their host SSH keys as secret recipients:

```sh
ssh-keyscan -t ed25519 192.168.2.81 192.168.2.82 192.168.2.83
ssh root@192.168.2.81 cat /etc/machine-id
ssh root@192.168.2.82 cat /etc/machine-id
ssh root@192.168.2.83 cat /etc/machine-id
```

All SSH host key fingerprints and all machine IDs should differ.

## Acceptance Criteria

Initial Setup is complete when:

- `thor` runs Proxmox.
- A reusable NixOS Proxmox VM template exists.
- Terraform can create all three Kubernetes node VMs from the template.
- NixOS configurations can be applied remotely with `nixos-rebuild --target-host`.
- k3s runs with one control-plane node and two worker nodes.
- `kubectl get nodes` shows all nodes as `Ready`.
- k3s local-path storage successfully provisions a test PVC.
- k3s default Traefik/ServiceLB exposes a sample app to the LAN.
- Setup instructions and required configuration values are documented in this repository.

## Roadmap

After Initial Setup:

- Add TrueNAS-backed Kubernetes storage.
- Add Immich and Audiobookshelf as first services.
- Add monitoring, dashboards, and alerting.
- Add Helmfile-managed cluster add-ons.
- Evaluate GitOps with Argo CD or Flux.
- Evaluate Colmena for multi-host NixOS deployment.
- Evaluate Cilium or another advanced Kubernetes networking stack.
- Move from single-host Proxmox VMs to multiple physical Kubernetes nodes when hardware is available.

## Open Questions

- What is the actual LAN CIDR, gateway, and DNS server?
- What static IP range is outside the DHCP pool?
- What is the Proxmox bridge name?
- What Proxmox storage pool should VM disks use?
- What NixOS template creation method will be used?
- Which local domain, if any, should be used for cluster services?
