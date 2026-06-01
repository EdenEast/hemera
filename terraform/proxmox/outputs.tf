output "cluster_nodes" {
  description = "Cluster Node inventory created by Terraform."
  value = {
    for name, node in local.cluster_nodes : name => {
      role                  = node.role
      ip                    = node.ip
      vm_id                 = node.vm_id
      longhorn_data_disk_gb = node.longhorn_data_disk_gb
    }
  }
}

output "cloud_init_user_data_file_ids" {
  description = "Proxmox snippet file IDs used for Cluster Node First Boot Configuration."
  value = {
    for name, file in proxmox_virtual_environment_file.cloud_init_user_data : name => file.id
  }
}
