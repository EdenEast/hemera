variable "proxmox_endpoint" {
  description = "Proxmox API endpoint for Thor, for example https://192.168.2.80:8006/."
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in provider-required format. Keep this out of git. TODO_CONFIRM after token creation."
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Whether to skip TLS verification for the Proxmox API. Usually true for the initial self-signed Thor install."
  type        = bool
  default     = true
}

variable "proxmox_node_name" {
  description = "Proxmox node name for Thor, for example pve."
  type        = string
}

variable "nixos_template_id" {
  description = "Proxmox VM/template ID for the reusable NixOS template. TODO_CONFIRM after template creation."
  type        = number
}

variable "proxmox_datastore_id" {
  description = "Proxmox datastore/storage ID for VM disks, for example local-lvm."
  type        = string
}

variable "proxmox_bridge" {
  description = "Proxmox network bridge for VM NICs."
  type        = string
  default     = "vmbr0"
}
