terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure

  # proxmox_virtual_environment_file uploads via ssh so ssh is required
  ssh {
    username = var.proxmox_ssh_username
    agent    = true

    node {
      name    = var.proxmox_node_name
      address = var.proxmox_node_address
    }
  }
}

locals {
  cluster_nodes = {
    k8s-cp-01 = {
      vm_id                 = 501
      role                  = "control-plane"
      ip                    = "192.168.2.81"
      cores                 = 2
      memory_mb             = 3072
      root_disk_gb          = 50
      longhorn_data_disk_gb = null
    }
    k8s-worker-01 = {
      vm_id                 = 511
      role                  = "worker"
      ip                    = "192.168.2.82"
      cores                 = 2
      memory_mb             = 4096
      root_disk_gb          = 80
      longhorn_data_disk_gb = 250
    }
    k8s-worker-02 = {
      vm_id                 = 512
      role                  = "worker"
      ip                    = "192.168.2.83"
      cores                 = 2
      memory_mb             = 4096
      root_disk_gb          = 80
      longhorn_data_disk_gb = 250
    }
  }
}

# Resource for first boot reachability only
resource "proxmox_virtual_environment_file" "cloud_init_user_data" {
  for_each     = local.cluster_nodes
  node_name    = var.proxmox_node_name
  datastore_id = var.proxmox_snippet_datastore_id
  content_type = "snippets"

  source_raw {
    file_name = "${each.key}-user-data.yaml"
    data = templatefile("${path.module}/templates/user-data.yaml.tftpl", {
      hostname             = each.key
      admin_ssh_public_key = var.admin_ssh_public_key
    })
  }
}

resource "proxmox_virtual_environment_vm" "cluster_node" {
  for_each = local.cluster_nodes

  name      = each.key
  node_name = var.proxmox_node_name
  vm_id     = each.value.vm_id
  tags      = ["hemera", each.value.role]
  started   = true

  clone {
    vm_id = var.nixos_template_id
    full  = true
  }

  agent { enabled = true }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory { dedicated = each.value.memory_mb }

  disk {
    datastore_id = var.proxmox_datastore_id
    interface    = "virtio0"
    size         = each.value.root_disk_gb
  }

  dynamic "disk" {
    for_each = each.value.longhorn_data_disk_gb == null ? [] : [each.value.longhorn_data_disk_gb]
    content {
      datastore_id = var.proxmox_datastore_id
      interface    = "virtio1"
      serial       = "longhorn-data"
      size         = disk.value
    }
  }

  network_device {
    bridge = var.proxmox_bridge
    model  = "virtio"
  }

  initialization {
    datastore_id      = var.proxmox_datastore_id
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_user_data[each.key].id

    dns { servers = ["192.168.2.1", "1.1.1.1", "9.9.9.9"] }

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = "192.168.2.1"
      }
    }
  }

  operating_system {
    type = "l26"
  }
}
