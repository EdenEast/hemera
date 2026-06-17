variable "proxmox_endpoint" {
  description = "Proxmox API endpoint for the cluster, for example https://192.168.2.51:8006/."
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in provider-required format. Keep this out of git."
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Whether to skip TLS verification for Proxmox self-signed certificates."
  type        = bool
  default     = true
}

variable "proxmox_node_01_address" {
  description = "SSH address for Proxmox node-01 / Thor. Also hosts the NixOS template."
  type        = string
  default     = "192.168.2.51"
}

variable "proxmox_node_02_address" {
  description = "SSH address for Proxmox node-02."
  type        = string
  default     = "192.168.2.52"
}

variable "proxmox_node_03_address" {
  description = "SSH address for Proxmox node-03."
  type        = string
  default     = "192.168.2.53"
}

variable "proxmox_ssh_username" {
  description = "SSH user for Proxmox snippet uploads."
  type        = string
  default     = "root"
}

variable "proxmox_snippet_datastore_id" {
  description = "Snippet-capable datastore ID on each Proxmox node."
  type        = string
  default     = "local"
}

variable "proxmox_bridge" {
  description = "Proxmox network bridge for VM NICs."
  type        = string
  default     = "vmbr0"
}

variable "template_source_node" {
  description = "Proxmox node containing the NixOS cloud-init template VM."
  type        = string
  default     = "node-01"
}

variable "nixos_template_id" {
  description = "Cluster-wide VM ID of the NixOS cloud-init template."
  type        = number
  default     = 9000
}

variable "admin_ssh_public_key" {
  description = "Local user's public SSH key for initial cloud-init access before Colmena takes over."
  type        = string
}
