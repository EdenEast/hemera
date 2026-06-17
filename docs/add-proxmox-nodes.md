# SOP: Add a Proxmox node to the Hemera cluster

## Purpose

This SOP describes how to add a new Proxmox VE host to the Hemera Proxmox cluster and complete the required post-join setup for Kubernetes VM hosting.

It covers:

- Proxmox host installation and network identity
- Joining the Proxmox cluster
- Storage setup
- HA Kubernetes API VIP proxy setup with HAProxy and Keepalived
- Terraform/Nix integration checks
- Validation and rollback

## Current cluster constants

| Component | Value |
|---|---|
| Proxmox bridge | `vmbr0` |
| LAN gateway | `192.168.2.1` |
| Kubernetes API VIP | `192.168.2.50` |
| VIP listener | `192.168.2.50:6443` |
| Keepalived VRID | `50` |
| Keepalived auth pass | `hemera50` |
| Existing Proxmox node 1 | `node-01` / `192.168.2.51` |
| Existing Proxmox node 2 | `node-02` / `192.168.2.52` |
| Existing Proxmox node 3 | `node-03` / `192.168.2.53` |
| Current K3s API backends | `192.168.2.81`, `192.168.2.56`, `192.168.2.58` |
| NixOS template VM ID | `9000` on `node-01` |

## Required inputs

Before starting, choose and record:

| Field | Example | Actual |
|---|---:|---:|
| New Proxmox hostname | `node-04` |  |
| New Proxmox management IP | `192.168.2.54` |  |
| Keepalived router ID | `NODE_04` |  |
| Keepalived priority | `90` |  |
| Proxmox root disk | `/dev/nvme0n1` |  |
| Longhorn storage disk | `/dev/sdb` |  |
| Longhorn storage ID | `longhorn-lvm` |  |

Keepalived priorities should be unique. Use lower priorities for newer or less preferred hosts. Current priorities:

| Host | Priority |
|---|---:|
| `node-01` | `120` |
| `node-02` | `110` |
| `node-03` | `100` |

For `node-04`, use `90` unless there is a reason to prefer it over an existing host.

## Safety rules

1. Do not change running Kubernetes workloads during Proxmox host onboarding unless explicitly required.
2. Do not run a blind Terraform apply after changing Proxmox cluster membership.
3. Do not duplicate VM/template ID `9000` on another Proxmox node unless the template strategy has intentionally changed.
4. Do not add a new HAProxy backend until the target K3s control-plane VM exists and is healthy.
5. Only one Proxmox host should own `192.168.2.50` at a time.

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

### 1.3 Confirm VIP ownership

```bash
for host in 192.168.2.51 192.168.2.52 192.168.2.53; do
  echo "=== $host ==="
  ssh root@$host 'hostname; systemctl is-active haproxy keepalived; ip addr show vmbr0 | grep 192.168.2.50 || true'
done
```

Expected:

- `haproxy` and `keepalived` are active on all participating Proxmox hosts.
- Exactly one host shows `192.168.2.50/24` on `vmbr0`.

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

From your workstation:

```bash
ping -c 3 192.168.2.54
ssh root@192.168.2.54 'hostname; ip -br addr; ip route'
```

Expected:

- Hostname matches the planned Proxmox node name.
- `vmbr0` has the planned static IP.
- Default route uses `192.168.2.1`.

### 2.3 Post install proxmox setup

After install run [PVE Post Install](https://community-scripts.org/scripts/post-pve-install?from=scripts&fromQ=post+install+&fromFilter=popular) script to remove enterprise repositories and nags

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

### 3.1 Get the cluster join command from an existing node

On an existing cluster node:

```bash
ssh root@192.168.2.51 'pvecm status'
```

Confirm quorum is healthy before continuing.

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

> Skip this section for control-plane-only Proxmox hosts.

Identify the dedicated Longhorn disk. Example: `/dev/sdb`.

Create a physical volume, volume group, and Proxmox LVM-thin storage:

```bash
ssh root@192.168.2.54 '
  pvcreate /dev/sdb
  vgcreate longhorn-vg /dev/sdb
  lvcreate -l 100%FREE -T longhorn-vg/longhorn-thin
  pvesm add lvmthin longhorn-lvm --vgname longhorn-vg --thinpool longhorn-thin --content images,rootdir
  pvesm status
'
```

Expected:

- `longhorn-lvm` appears in `pvesm status`.

If Terraform manages this storage for the host, make sure the Terraform resource matches the actual state before applying.

---

## Phase 5: Install HA Kubernetes API VIP proxy components

Do this if the new Proxmox host should participate in API VIP failover.

### 5.1 Install packages

```bash
ssh root@192.168.2.54 'apt update && apt install -y haproxy keepalived'
```

### 5.2 Allow HAProxy to bind the VIP when not currently master

```bash
ssh root@192.168.2.54 'echo net.ipv4.ip_nonlocal_bind=1 >/etc/sysctl.d/99-k8s-api-vip.conf && sysctl --system'
```

Validate:

```bash
ssh root@192.168.2.54 'sysctl net.ipv4.ip_nonlocal_bind'
```

Expected:

```text
net.ipv4.ip_nonlocal_bind = 1
```

### 5.3 Configure HAProxy

Write `/etc/haproxy/haproxy.cfg` on the new node:

```bash
ssh root@192.168.2.54 "cat >/etc/haproxy/haproxy.cfg <<'EOF'
global
  log /dev/log local0
  log /dev/log local1 notice

defaults
  log global
  mode tcp
  option tcplog
  timeout connect 5s
  timeout client  1m
  timeout server  1m

frontend k8s_api
  bind 192.168.2.50:6443
  default_backend k8s_api_backends

backend k8s_api_backends
  option tcp-check
  server k8s-cp-01 192.168.2.81:6443 check
  server k8s-cp-02 192.168.2.56:6443 check
  server k8s-cp-03 192.168.2.58:6443 check
EOF
haproxy -c -f /etc/haproxy/haproxy.cfg
systemctl enable --now haproxy
systemctl restart haproxy
systemctl is-active haproxy
"
```

Expected:

- `haproxy -c` reports valid config.
- `haproxy` is active.

### 5.4 Configure Keepalived

Set these values for the new node:

```bash
NEW_NODE_IP=192.168.2.54
ROUTER_ID=NODE_04
PRIORITY=90
```

Write config:

```bash
ssh root@$NEW_NODE_IP "cat >/etc/keepalived/keepalived.conf <<EOF
global_defs {
  router_id ${ROUTER_ID}
}

vrrp_script chk_haproxy {
  script \"pidof haproxy\"
  interval 2
  fall 2
  rise 2
  weight -20
}

vrrp_instance VI_K8S_API {
  state BACKUP
  interface vmbr0
  virtual_router_id 50
  priority ${PRIORITY}
  advert_int 1

  authentication {
    auth_type PASS
    auth_pass hemera50
  }

  virtual_ipaddress {
    192.168.2.50/24 dev vmbr0
  }

  track_script {
    chk_haproxy
  }
}
EOF
systemctl enable --now keepalived
systemctl restart keepalived
systemctl is-active keepalived
"
```

### 5.5 Validate VIP state

```bash
for host in 192.168.2.51 192.168.2.52 192.168.2.53 192.168.2.54; do
  echo "=== $host ==="
  ssh root@$host 'hostname; systemctl is-active haproxy keepalived; ip addr show vmbr0 | grep 192.168.2.50 || true'
done

ping -c 3 192.168.2.50
kubectl --server=https://192.168.2.50:6443 get nodes -o wide
```

Expected:

- Exactly one Proxmox host owns `192.168.2.50/24`.
- VIP API works.

---

## Phase 6: Optional VIP failover test

Only run this during a maintenance window or while actively supervising the cluster.

### 6.1 Identify current VIP owner

```bash
for host in 192.168.2.51 192.168.2.52 192.168.2.53 192.168.2.54; do
  ssh root@$host 'hostname; ip addr show vmbr0 | grep 192.168.2.50 || true'
done
```

### 6.2 Stop Keepalived on current owner

Replace `CURRENT_OWNER_IP` with the node currently holding the VIP:

```bash
ssh root@CURRENT_OWNER_IP 'systemctl stop keepalived'
```

### 6.3 Confirm failover

```bash
for host in 192.168.2.51 192.168.2.52 192.168.2.53 192.168.2.54; do
  ssh root@$host 'hostname; ip addr show vmbr0 | grep 192.168.2.50 || true'
done

kubectl --server=https://192.168.2.50:6443 get nodes
```

Expected:

- Another host owns `192.168.2.50`.
- Kubernetes API remains reachable.

### 6.4 Restore original node

```bash
ssh root@CURRENT_OWNER_IP 'systemctl start keepalived'
```

---

## Phase 7: Template and VM placement setup

### 7.1 Confirm template strategy

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

### 7.2 Validate VM networking on new node

```bash
ssh root@192.168.2.54 'ip -br link show vmbr0; bridge link || true'
```

Expected:

- `vmbr0` exists and is up.
- VMs attached to `vmbr0` will land on the LAN.

---

## Phase 8: Terraform integration

### 8.1 Update Terraform variables if needed

If Terraform needs to SSH to the new Proxmox node for snippets or VM creation, add a variable for the new node address in `terraform/proxmox` as required by the Terraform module design.

Example local value:

```hcl
proxmox_node_04_address = "192.168.2.54"
```

### 8.2 Add the new node to VM placement maps

When adding VMs that should run on the new node, update the relevant Terraform map with:

- Proxmox node name, e.g. `node-04`
- VM ID
- VM IP
- root datastore, usually `local-lvm`
- Longhorn datastore, usually `longhorn-lvm` for workers

Review before applying:

```bash
terraform -chdir=terraform/proxmox fmt -check
terraform -chdir=terraform/proxmox validate
terraform -chdir=terraform/proxmox plan
```

Do not apply if Terraform wants to destroy or recreate existing VMs unexpectedly.

---

## Phase 9: Nix/Kubernetes integration for new VMs

This phase is only needed after Terraform creates new Kubernetes VMs on the Proxmox node.

### 9.1 Add Nix host definitions

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

### 9.2 Verify IPs before applying

Before running Colmena, verify the target host IP in Nix matches the actual VM:

```bash
rg -n 'hostName|address = ' nix/hosts/<hostname>/configuration.nix
ping -c 3 <vm-ip>
ssh admin@<vm-ip> 'hostname; ip -br addr; lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL'
```

For Longhorn workers, expected disk:

```text
/dev/disk/by-id/virtio-longhorn-data
```

### 9.3 Deploy with Colmena

```bash
export HEMERA_AGE_KEY=/home/eden/c/hemera/keys.txt
nix run github:zhaofengli/colmena -- apply --on <hostname>
```

### 9.4 Validate Kubernetes node

```bash
kubectl get nodes -o wide
kubectl wait node/<hostname> --for=condition=Ready --timeout=10m
```

For workers:

```bash
ssh admin@<vm-ip> 'findmnt /var/lib/longhorn; lsblk -f'
kubectl get pods -n longhorn-system -o wide | grep <hostname>
```

---

## Phase 10: Final validation checklist

Run all checks before declaring the node ready.

### 10.1 Proxmox checks

```bash
ssh root@192.168.2.54 'hostname; pvecm status; pvesm status; qm list'
```

Expected:

- Node is in the cluster.
- Cluster is quorate.
- Storage is healthy.

### 10.2 VIP checks

```bash
for host in 192.168.2.51 192.168.2.52 192.168.2.53 192.168.2.54; do
  echo "=== $host ==="
  ssh root@$host 'hostname; systemctl is-active haproxy keepalived; ip addr show vmbr0 | grep 192.168.2.50 || true; grep -E "server k8s-cp" /etc/haproxy/haproxy.cfg'
done

kubectl --server=https://192.168.2.50:6443 get nodes -o wide
```

Expected:

- HAProxy/Keepalived active on VIP participants.
- Exactly one VIP owner.
- HAProxy backend list is current.
- Kubernetes API works through VIP.

### 10.3 Kubernetes checks

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

### If VIP breaks

1. Stop Keepalived on the new node:

```bash
ssh root@192.168.2.54 'systemctl stop keepalived'
```

2. Confirm an existing node owns the VIP:

```bash
for host in 192.168.2.51 192.168.2.52 192.168.2.53; do
  ssh root@$host 'hostname; ip addr show vmbr0 | grep 192.168.2.50 || true'
done
```

3. Validate Kubernetes API:

```bash
kubectl --server=https://192.168.2.50:6443 get nodes
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
