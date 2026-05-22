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
}

locals {
  cluster_nodes = {
    k8s-cp-01 = {
      vm_id                 = 501
      role                  = "control-plane"
      ip                    = "192.168.2.81"
      cores                 = 2
      memory_mb             = 3072
      memory_floating_mb    = 1536
      root_disk_gb          = 40
      longhorn_data_disk_gb = null
    }
    k8s-worker-01 = {
      vm_id                 = 511
      role                  = "worker"
      ip                    = "192.168.2.82"
      cores                 = 2
      memory_mb             = 3072
      memory_floating_mb    = 1024
      root_disk_gb          = 60
      longhorn_data_disk_gb = 250
    }
    k8s-worker-02 = {
      vm_id                 = 512
      role                  = "worker"
      ip                    = "192.168.2.83"
      cores                 = 2
      memory_mb             = 3072
      memory_floating_mb    = 1024
      root_disk_gb          = 60
      longhorn_data_disk_gb = 250
    }
  }
}

resource "proxmox_virtual_environment_vm" "cluster_node" {
  for_each = local.cluster_nodes

  name       = each.key
  node_name  = var.proxmox_node_name
  vm_id      = each.value.vm_id
  tags       = ["hemera", "initial-setup", each.value.role]
  boot_order = ["virtio0"]
  started    = true

  description = "Hemera Initial Setup ${each.value.role} Cluster Node. OS and k3s state are managed by NixOS, not Terraform."

  agent {
    enabled = true
  }

  clone {
    vm_id = var.nixos_template_id
    full  = true
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory_mb
    floating  = each.value.memory_floating_mb
  }

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
    datastore_id = var.proxmox_datastore_id
    interface    = "ide2"

    dns {
      servers = ["192.168.2.1"]
    }

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

  lifecycle {
    ignore_changes = [
      # Clone settings are creation-time inputs. Existing Cluster Nodes were
      # imported into Terraform state, so changing this block would otherwise
      # force VM replacement instead of managing the already-running VMs.
      clone,
      initialization,
      keyboard_layout,
      scsi_hardware,
      serial_device,
    ]
  }
}
