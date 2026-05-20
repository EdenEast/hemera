variable "proxmox_endpoint" {
  description = "Proxmox API endpoint for Thor, for example https://192.168.1.10:8006/. TODO_CONFIRM after Proxmox is installed."
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
  description = "Proxmox node name for Thor. TODO_CONFIRM after Proxmox is installed."
  type        = string
}

variable "nixos_template_id" {
  description = "Proxmox VM/template ID for the reusable NixOS template. TODO_CONFIRM after template creation."
  type        = number
}

variable "proxmox_datastore_id" {
  description = "Proxmox datastore/storage ID for VM disks. TODO_CONFIRM after Proxmox storage is configured."
  type        = string
}

variable "proxmox_bridge" {
  description = "Proxmox network bridge for VM NICs. TODO_CONFIRM after Proxmox networking is configured."
  type        = string
  default     = "vmbr0"
}
