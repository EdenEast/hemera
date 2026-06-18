# SOP: Add a Proxmox node to the Hemera cluster

## Purpose

This SOP describes how to add a new Proxmox VE host to the Hemera Proxmox cluster and prepare it for Kubernetes VM hosting.

It covers:

- Proxmox host installation and network identity
- Joining the Proxmox cluster
- Storage setup
- Terraform/Nix integration checks
- kube-vip validation for the Kubernetes API VIP
- Validation and rollback

## Current cluster constants

| Component | Value |
|---|---|
| Proxmox bridge | `vmbr0` |
| LAN gateway | `192.168.2.1` |
| Kubernetes API VIP | `192.168.2.50` |
| VIP listener | `192.168.2.50:6443` |
| VIP implementation | `kube-vip` DaemonSet in `kube-system` |
| Existing Proxmox node 1 | `node-01` / `192.168.2.51` |
| Existing Proxmox node 2 | `node-02` / `192.168.2.52` |
| Existing Proxmox node 3 | `node-03` / `192.168.2.53` |
| Current K3s control planes | `k8s-cp-01`, `k8s-cp-02`, `k8s-cp-03` |
| NixOS template VM ID | `9000` on `node-01` |

## Required inputs

Before starting, choose and record:

| Field | Example | Actual |
|---|---:|---:|
| New Proxmox hostname | `node-04` |  |
| New Proxmox management IP | `192.168.2.54` |  |
| Proxmox root disk | `/dev/nvme0n1` |  |
| Longhorn storage disk | `/dev/sdb` |  |
| Longhorn storage ID | `longhorn-lvm` |  |

## Safety rules

1. Do not change running Kubernetes workloads during Proxmox host onboarding unless explicitly required.
2. Do not run a blind Terraform apply after changing Proxmox cluster membership.
3. Do not duplicate VM/template ID `9000` on another Proxmox node unless the template strategy has intentionally changed.
4. Do not create a separate Proxmox-hosted Kubernetes API VIP. Hemera uses kube-vip inside the Kubernetes cluster.
5. Only one control-plane Cluster Node should own `192.168.2.50` at a time.

---

## Phase 1: Preflight checks

Run from your workstation.

### 1.1 Confirm current Proxmox cluster health

```bash
for host in 192.168.2.51 192.168.2.52 192.168.2.53; do
  echo "=== $host ==="
  ssh root@$host 'hostname; pvecm status; pvesm status'
done
```

Expected:

- All existing nodes are visible in `pvecm status`.
- Quorum is healthy.
- Existing storage is available.

### 1.2 Confirm current Kubernetes health

```bash
kubectl get nodes -o wide
kubectl get pods -A | grep -v ' Running ' | grep -v ' Completed ' || true
kubectl --server=https://192.168.2.50:6443 get nodes -o wide
```

Expected:

- All expected Kubernetes nodes are `Ready`.
- VIP API works.

### 1.3 Confirm kube-vip health

```bash
kubectl -n kube-system get daemonset kube-vip-ds
kubectl -n kube-system get pods -l app.kubernetes.io/name=kube-vip -o wide
kubectl -n kube-system logs daemonset/kube-vip-ds --tail=50
```

To identify the current VIP owner, check the control-plane Cluster Nodes:

```bash
for host in 192.168.2.54 192.168.2.56 192.168.2.58; do
  echo "=== $host ==="
  ssh admin@$host 'hostname; ip addr show eth0 | grep 192.168.2.50 || true'
done
```

Expected:

- `kube-vip-ds` is available.
- kube-vip pods are running on control-plane Cluster Nodes.
- Exactly one control-plane Cluster Node shows `192.168.2.50/24` on `eth0`.

---

## Phase 2: Install and prepare the new Proxmox host

### 2.1 Install Proxmox VE

Install the same major Proxmox VE version as the existing cluster.

During installation configure:

- Hostname: the chosen node name, e.g. `node-04`
- Management IP: the chosen static IP, e.g. `192.168.2.54/24`
- Gateway: `192.168.2.1`
- DNS: `192.168.2.1`, plus public fallback if desired

### 2.2 Confirm network identity

```bash
ping -c 3 192.168.2.54
ssh root@192.168.2.54 'hostname; ip -br addr; ip route'
```

Expected:

- Hostname matches the planned Proxmox node name.
- `vmbr0` has the planned static IP.
- Default route uses `192.168.2.1`.

### 2.3 Post-install Proxmox setup

After install, run the [PVE Post Install](https://community-scripts.org/scripts/post-pve-install?from=scripts&fromQ=post+install+&fromFilter=popular) script if desired to remove enterprise repositories and nags.

### 2.4 Update host resolution on all Proxmox nodes

On every Proxmox node, including the new one, ensure `/etc/hosts` has all cluster nodes.

Example:

```bash
for host in 192.168.2.51 192.168.2.52 192.168.2.53 192.168.2.54; do
  ssh root@$host 'cp /etc/hosts /etc/hosts.bak.$(date +%Y%m%d-%H%M%S)'
  ssh root@$host 'grep -q "192.168.2.54 node-04" /etc/hosts || echo "192.168.2.54 node-04" >>/etc/hosts'
done
```

Validate:

```bash
for host in 192.168.2.51 192.168.2.52 192.168.2.53 192.168.2.54; do
  echo "=== $host ==="
  ssh root@$host 'getent hosts node-01 node-02 node-03 node-04'
done
```

---

## Phase 3: Join the Proxmox cluster

### 3.1 Confirm existing cluster quorum

```bash
ssh root@192.168.2.51 'pvecm status'
```

### 3.2 Join from the new node

Run on the new node, pointing at an existing cluster member:

```bash
ssh root@192.168.2.54 'pvecm add 192.168.2.51'
```

Follow prompts. Use the root password or configured SSH trust as required.

### 3.3 Validate cluster membership

```bash
for host in 192.168.2.51 192.168.2.54; do
  echo "=== $host ==="
  ssh root@$host 'hostname; pvecm nodes; pvecm status'
done
```

Expected:

- New node appears in `pvecm nodes`.
- Cluster remains quorate.

---

## Phase 4: Configure Proxmox storage

### 4.1 Check storage inventory

```bash
ssh root@192.168.2.54 'lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL'
ssh root@192.168.2.54 'pvesm status'
```

### 4.2 Confirm default Proxmox local storage

Expected default local storage:

- `local`
- `local-lvm`

If `local-lvm` is missing, stop and fix the Proxmox installation/storage layout before using the node for Terraform-created VMs.

### 4.3 Create Longhorn LVM storage if this node will host Longhorn workers

Skip this section for control-plane-only Proxmox hosts.

Identify the dedicated Longhorn disk. Example: `/dev/sdb`.

```bash
ssh root@192.168.2.54 '
  pvcreate /dev/sdb
  vgcreate vg-longhorn /dev/sdb
  lvcreate -l 100%FREE -T vg-longhorn/longhorn
  pvesm add lvmthin longhorn-lvm --vgname vg-longhorn --thinpool longhorn --content images,rootdir
  pvesm status
'
```

Expected:

- `longhorn-lvm` appears in `pvesm status`.

If Terraform manages this storage for the host, make sure the Terraform resource matches the actual state before applying.

---

## Phase 5: Template and VM placement setup

### 5.1 Confirm template strategy

Current template strategy:

- NixOS template VM ID `9000` exists on `node-01`.
- Terraform cross-node clones from `node-01`.
- Do not create a duplicate local `9000` template on the new node unless the strategy changes.

Validate:

```bash
ssh root@192.168.2.51 'qm status 9000 && qm config 9000 | grep -E "^template: 1|^name:"'
ssh root@192.168.2.54 'qm status 9000 || true'
```

Expected:

- `node-01` has template `9000`.
- The new node does not have a conflicting local VM/template ID `9000`.

### 5.2 Validate VM networking on new node

```bash
ssh root@192.168.2.54 'ip -br link show vmbr0; bridge link || true'
```

Expected:

- `vmbr0` exists and is up.
- VMs attached to `vmbr0` will land on the LAN.

---

## Phase 6: Terraform integration

### 6.1 Update Terraform node inventory

If Terraform needs to create VMs on the new Proxmox node, add the node to the Proxmox provider SSH node list and to any placement maps in `terraform/proxmox/main.tf`.

Record for each new VM:

- Proxmox node name, e.g. `node-04`
- VM ID
- VM IP
- role: `control-plane` or `worker`
- root datastore, usually `local-lvm`
- Longhorn datastore, usually `longhorn-lvm` for workers

### 6.2 Review Terraform safely

```bash
terraform -chdir=terraform/proxmox fmt -check
terraform -chdir=terraform/proxmox validate
terraform -chdir=terraform/proxmox plan
```

Do not apply if Terraform wants to destroy or recreate existing VMs unexpectedly.

---

## Phase 7: Nix/Kubernetes integration for new VMs

This phase is only needed after Terraform creates new Kubernetes VMs on the Proxmox node.

### 7.1 Add Nix host definitions

Create or update host files under:

```text
nix/hosts/<hostname>/configuration.nix
```

Control-plane nodes should import:

```nix
../../modules/common.nix
../../modules/k3s-server.nix
```

Worker nodes should import:

```nix
../../modules/common.nix
../../modules/k3s-agent.nix
../../modules/longhorn-data-disk.nix
```

Workers with dedicated Longhorn disks should include:

```nix
hemera.longhornDataDisk.enable = true;
```

### 7.2 Verify IPs before applying

```bash
rg -n 'hostName|address = ' nix/hosts/<hostname>/configuration.nix
ping -c 3 <vm-ip>
ssh admin@<vm-ip> 'hostname; ip -br addr; lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL'
```

For Longhorn workers, expected disk:

```text
/dev/disk/by-id/virtio-longhorn-data
```

### 7.3 Deploy with Colmena

```bash
export HEMERA_AGE_KEY=/home/eden/c/hemera/keys.txt
nix run github:zhaofengli/colmena -- apply --on <hostname>
```

### 7.4 Validate Kubernetes node

```bash
kubectl get nodes -o wide
kubectl wait node/<hostname> --for=condition=Ready --timeout=10m
```

For workers:

```bash
ssh admin@<vm-ip> 'findmnt /var/lib/longhorn; lsblk -f'
kubectl get pods -n longhorn-system -o wide | grep <hostname>
```

For control-plane nodes, kube-vip should automatically schedule on the node after it has the `node-role.kubernetes.io/control-plane` label:

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/name=kube-vip -o wide
kubectl --server=https://192.168.2.50:6443 get nodes -o wide
```

---

## Phase 8: Final validation checklist

### 8.1 Proxmox checks

```bash
ssh root@192.168.2.54 'hostname; pvecm status; pvesm status; qm list'
```

Expected:

- Node is in the cluster.
- Cluster is quorate.
- Storage is healthy.

### 8.2 kube-vip checks

```bash
kubectl -n kube-system get daemonset kube-vip-ds
kubectl -n kube-system get pods -l app.kubernetes.io/name=kube-vip -o wide
kubectl --server=https://192.168.2.50:6443 get nodes -o wide
```

Expected:

- kube-vip pods are healthy on control-plane Cluster Nodes.
- The Kubernetes API works through `192.168.2.50:6443`.

### 8.3 Kubernetes checks

```bash
kubectl get nodes -o wide
kubectl get pods -A | grep -v ' Running ' | grep -v ' Completed ' || true
```

Expected:

- Nodes are `Ready`.
- No unexpected failing pods.

---

## Rollback

### If Proxmox cluster join fails

Do not retry repeatedly without checking logs.

On the new node:

```bash
journalctl -u corosync -u pve-cluster --no-pager -n 200
```

If the node partially joined and must be removed, follow Proxmox cluster removal procedures from a healthy existing node. Do not remove a node from a non-quorate cluster without a recovery plan.

### If kube-vip or the API VIP breaks

1. Check kube-vip pods and logs:

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/name=kube-vip -o wide
kubectl -n kube-system logs daemonset/kube-vip-ds --tail=100
```

2. Confirm whether any control-plane node owns the VIP:

```bash
for host in 192.168.2.54 192.168.2.56 192.168.2.58; do
  echo "=== $host ==="
  ssh admin@$host 'hostname; ip addr show eth0 | grep 192.168.2.50 || true'
done
```

3. Validate Kubernetes API:

```bash
kubectl --server=https://192.168.2.50:6443 get nodes
```

If the VIP is unavailable but a control-plane node is reachable, temporarily fetch a kubeconfig that points directly at that node while repairing kube-vip:

```bash
CONTROL_PLANE_IP=<control-plane-ip> \
KUBE_API_ENDPOINT=https://<control-plane-ip>:6443 \
just kubeconfig
```

### If Terraform plan is unsafe

Stop. Do not apply. Save the plan and reconcile state/imports first.

```bash
terraform -chdir=terraform/proxmox plan | tee ../../backups/proxmox-node-add-$(date +%F)-plan.txt
```

### If a Kubernetes VM receives the wrong Nix config

1. Fix the IP/host mapping in `nix/hosts/<hostname>/configuration.nix`.
2. Re-apply the correct config to the affected host.
3. If K3s registered a duplicate/wrong node, delete the bad node and node password secret:

```bash
kubectl delete node <hostname> --ignore-not-found=true
kubectl -n kube-system delete secret <hostname>.node-password.k3s --ignore-not-found=true
ssh admin@<correct-ip> 'sudo rm -f /etc/rancher/node/password; sudo systemctl restart k3s'
kubectl wait node/<hostname> --for=condition=Ready --timeout=10m
```
