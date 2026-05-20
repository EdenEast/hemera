# Hemera

Hemera is a homelab platform used to run internal self-hosted services and demonstrate DevOps practices on personally owned hardware.

## Language

**Initial Setup**:
The first delivery milestone for Hemera: a Proxmox host on `thor`, Terraform-managed virtual Kubernetes nodes, and a functional Kubernetes cluster ready for later service deployment.
_Avoid_: full homelab, monitoring phase, Nix phase

**Thor**:
The desktop computer that serves as Hemera's initial Proxmox host.
_Avoid_: old desktop, server, machine

**TrueNAS**:
The storage appliance available to Hemera for network-backed storage.
_Avoid_: NAS, storage box

**Cluster Node**:
A virtual or physical machine that participates in Hemera's Kubernetes cluster.
_Avoid_: Kubernetes machine, guest, instance

**Node Configuration**:
The desired operating-system-level state of a Cluster Node.
_Avoid_: Ansible config, bootstrap script, machine setup

## Relationships

- **Initial Setup** runs on **Thor**.
- **Initial Setup** may use **TrueNAS** for storage, but does not require full storage automation.
- A **Cluster Node** initially runs as a virtual machine on **Thor** and may later move to dedicated hardware.
- **Node Configuration** belongs to each **Cluster Node**.

## Example dialogue

> **Dev:** "Does the **Initial Setup** include monitoring and alerting?"
> **Domain expert:** "No — the **Initial Setup** ends once **Thor** runs Terraform-provisioned Kubernetes nodes as a functional cluster."

## Flagged ambiguities

- "initial setup" could mean anything from Proxmox installation through monitoring; resolved: **Initial Setup** means Proxmox on **Thor**, Terraform-managed Kubernetes nodes, and a functional Kubernetes cluster.
