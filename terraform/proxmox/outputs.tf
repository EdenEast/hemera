output "cluster_nodes" {
  description = "Declared Hemera Initial Setup Cluster Nodes and their intended management IPs."
  value = {
    for name, node in local.cluster_nodes : name => {
      vm_id                 = node.vm_id
      name                  = name
      role                  = node.role
      ip                    = node.ip
      root_disk_gb          = node.root_disk_gb
      longhorn_data_disk_gb = node.longhorn_data_disk_gb
    }
  }
}

output "cluster_node_ips" {
  description = "Intended static management IPs configured later by NixOS Node Configuration."
  value = {
    for name, node in local.cluster_nodes : name => node.ip
  }
}
