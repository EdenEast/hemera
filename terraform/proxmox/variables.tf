variable "proxmox_endpoint" {
  description = "Proxmox API endpoint for proxmox, for example https://192.168.2.80:8006/."
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

variable "proxmox_datastore_id" {
  description = "Proxmox datastore/storage ID for VM disks, for example local-lvm."
  type        = string
}

variable "proxmox_snippet_datastore_id" {
  type    = string
  default = "local"
}

variable "proxmox_bridge" {
  description = "Proxmox network bridge for VM NICs."
  type        = string
  default     = "vmbr0"
}

variable "proxmox_node_address" {
  description = "SSH address for the Thor Proxmox node."
  type        = string
  default     = "192.168.2.80"
}

variable "proxmox_ssh_username" {
  description = "SSH user for Proxmox file uploads."
  type        = string
  default     = "root"
}

variable "nixos_template_id" { type = number }

variable "admin_ssh_public_key" {
  description = "Local user's public ssh key to allow initial ssh connection to cloud-init template"
  type        = string
}
