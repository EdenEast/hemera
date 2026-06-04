# Hemera

Hemera is a homelab Kubernetes platform running on personally owned hardware.

## Language

**Cluster Node**:
A virtual or physical machine that participates in Hemera's Kubernetes cluster.
_Avoid_: Kubernetes machine, guest, instance

**Control Plane Node**:
A Cluster Node responsible for Kubernetes control-plane responsibilities. Hemera starts with one Control Plane Node because Thor's memory is limited.
_Avoid_: master, controller VM

**Worker Node**:
A Cluster Node intended to run application workloads and Longhorn Storage replicas.
_Avoid_: compute node, app VM

**Node Operating System**:
The operating system installed on each Cluster Node.
_Avoid_: node image, Linux distro, machine OS

**First Boot Configuration**:
The minimal configuration applied when a Cluster Node first starts so it becomes reachable for later management.
_Avoid_: bootstrap, cluster install, full node setup

**Bootstrap Step**:
A repeatable operator-run step that turns reachable Cluster Nodes into members of the Kubernetes cluster. Hemera uses Colmena for NixOS deployment during this step.
_Avoid_: Terraform provisioner, first boot, manual install

**Manual Apply Phase**:
A temporary operating mode where Kubernetes resources are organized as future GitOps inputs but applied manually by the operator.
_Avoid_: ad-hoc kubectl, live edits, permanent manual deployment

**Longhorn Storage**:
Replicated Kubernetes block storage used for stateful application data and configuration that must survive Cluster Node drains or VM-level failures while Thor remains healthy. Hemera hosts Longhorn Storage on Worker Nodes, not Control Plane Nodes.
_Avoid_: shared disk, backup storage, media storage

**Media Storage**:
Large media files stored outside Longhorn Storage on a TrueNAS NFS share and mounted directly into Kubernetes workloads through static Kubernetes PersistentVolumes. Some applications may write library-adjacent metadata or artwork beside the media when that is part of the media library workflow; write access should be scoped to the specific application that needs it.
_Avoid_: Longhorn media PVC, app config storage, backup storage, host-level media mount

**Application State**:
Application-owned configuration, databases, and internal metadata that should move with workloads through Longhorn Storage.
_Avoid_: media files, library-adjacent metadata, backups
