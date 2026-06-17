output "cluster_nodes" {
  description = "Final Kubernetes VM inventory managed by this Terraform root."
  value = {
    for name, node in local.cluster_nodes : name => {
      role                  = node.role
      ip                    = node.ip
      vm_id                 = node.vm_id
      proxmox_node          = node.proxmox_node
      root_disk_gb          = node.root_disk_gb
      longhorn_data_disk_gb = node.longhorn_data_disk_gb
    }
  }
}

output "cloud_init_user_data_file_ids" {
  description = "Proxmox snippet file IDs used for first boot configuration."
  value = {
    for name, file in proxmox_virtual_environment_file.cloud_init_user_data : name => file.id
  }
}

output "longhorn_lvmthin_storage_id" {
  description = "Proxmox storage ID for the node-02/node-03 Longhorn LVM-thin pool."
  value       = proxmox_storage_lvmthin.longhorn.id
}
