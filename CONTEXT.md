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
A temporary operating mode where Cluster Resources are organized as future GitOps inputs but applied manually by the operator.
_Avoid_: ad-hoc kubectl, live edits, permanent manual deployment

**GitOps Managed Phase**:
An operating mode where Cluster Resources are reconciled from the repository by an in-cluster GitOps system after the cluster itself exists.
_Avoid_: manual apply phase, live cluster ownership, post-bootstrap scripting

**Node Management**:
The responsibility area for creating, configuring, and maintaining Cluster Nodes themselves rather than resources running inside Kubernetes.
_Avoid_: cluster apps, platform components, GitOps resources

**Cluster Resource**:
A Kubernetes resource that runs inside or configures the cluster and is eligible for GitOps ownership once bootstrap is complete.
_Avoid_: node configuration, virtual machine lifecycle, operating system setup

**Control Cluster**:
The Kubernetes cluster where Hemera's active Argo CD instance runs.
_Avoid_: Argo cluster, Argo CD cluster

**Managed Cluster**:
A Kubernetes cluster reconciled by Hemera's Argo CD instance.
_Avoid_: remote cluster, target cluster, Argo cluster

**Self-Managed Cluster**:
A Kubernetes cluster that both runs Hemera's Argo CD instance and is reconciled by that same Argo CD instance. In Hemera, an unqualified "cluster" means Self-Managed Cluster unless another topology is explicitly named.
_Avoid_: local cluster, in-cluster target, Argo cluster

**GitOps Root Application**:
The top-level GitOps entrypoint that connects a cluster to the repository areas it should reconcile.
_Avoid_: one giant app, manual apply list, bootstrap script

**Cluster Entry Point**:
The cluster-specific set of GitOps resources that declares which repository areas a cluster reconciles.
_Avoid_: Flux sync folder, manual apply list, environment overlay

**GitOps Component**:
A repository directory for one platform service, operator, access service, storage service, or application that is reconciled by the GitOps system as a single unit.
_Avoid_: Helmfile release, direct Helm application, loose manifest folder

**GitOps Handoff**:
The final operator-run step that gives an in-cluster GitOps system ownership of Kubernetes resources after cluster creation and bootstrap are complete.
_Avoid_: continuous manual apply, hidden bootstrap, live deployment script

**GitOps Repository Credential**:
A private credential that allows the in-cluster GitOps system to read the repository it reconciles.
_Avoid_: GitHub account token, application secret, cluster secret

**Longhorn Storage**:
Replicated Kubernetes block storage used for stateful application data and configuration that must survive Cluster Node drains or VM-level failures while Thor remains healthy. Hemera hosts Longhorn Storage on Worker Nodes, not Control Plane Nodes.
_Avoid_: shared disk, backup storage, media storage

**Media Storage**:
Large media files stored outside Longhorn Storage on a TrueNAS NFS share and mounted directly into Kubernetes workloads through static Kubernetes PersistentVolumes. Some applications may write library-adjacent metadata or artwork beside the media when that is part of the media library workflow; write access should be scoped to the specific application that needs it.
_Avoid_: Longhorn media PVC, app config storage, backup storage, host-level media mount

**Application State**:
Application-owned configuration, databases, and internal metadata that should move with workloads through Longhorn Storage.
_Avoid_: media files, library-adjacent metadata, backups
