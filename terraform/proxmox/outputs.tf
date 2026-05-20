output "cluster_nodes" {
  description = "Declared Hemera Initial Setup Cluster Nodes and their intended management IPs."
  value = {
    for name, node in local.cluster_nodes : name => {
      vm_id = proxmox_virtual_environment_vm.cluster_node[name].vm_id
      name  = proxmox_virtual_environment_vm.cluster_node[name].name
      role  = node.role
      ip    = node.ip
    }
  }
}

output "cluster_node_ips" {
  description = "Intended static management IPs configured later by NixOS Node Configuration."
  value = {
    for name, node in local.cluster_nodes : name => node.ip
  }
}
