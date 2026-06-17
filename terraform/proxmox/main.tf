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
  insecure  = true

  # Snippet uploads use SSH. List every Proxmox node that can host VMs.
  ssh {
    username = var.proxmox_ssh_username
    agent    = true

    node {
      name    = "node-01"
      address = "192.168.2.51"
    }

    node {
      name    = "node-02"
      address = "192.168.2.52"
    }

    node {
      name    = "node-03"
      address = "192.168.2.53"
    }
  }
}

locals {
  cluster_nodes = {
    k8s-cp-01 = {
      vm_id                 = 501
      proxmox_node          = "node-01"
      role                  = "control-plane"
      ip                    = "192.168.2.54"
      cores                 = 2
      memory_mb             = 4096
      root_disk_gb          = 40
      root_datastore_id     = "local-lvm"
      longhorn_data_disk_gb = null
      longhorn_datastore_id = null
    }
    k8s-worker-01 = {
      vm_id                 = 511
      proxmox_node          = "node-01"
      role                  = "worker"
      ip                    = "192.168.2.55"
      cores                 = 2
      memory_mb             = 10240
      root_disk_gb          = 40
      root_datastore_id     = "local-lvm"
      longhorn_data_disk_gb = 400
      longhorn_datastore_id = "local-lvm"
    }
    k8s-cp-02 = {
      vm_id                 = 502
      proxmox_node          = "node-02"
      role                  = "control-plane"
      ip                    = "192.168.2.56"
      cores                 = 1
      memory_mb             = 4096
      root_disk_gb          = 40
      root_datastore_id     = "local-lvm"
      longhorn_data_disk_gb = null
      longhorn_datastore_id = null
    }
    k8s-worker-02 = {
      vm_id                 = 512
      proxmox_node          = "node-02"
      role                  = "worker"
      ip                    = "192.168.2.57"
      cores                 = 2
      memory_mb             = 10240
      root_disk_gb          = 40
      root_datastore_id     = "local-lvm"
      longhorn_data_disk_gb = 400
      longhorn_datastore_id = "longhorn-lvm"
    }
    k8s-cp-03 = {
      vm_id                 = 503
      proxmox_node          = "node-03"
      role                  = "control-plane"
      ip                    = "192.168.2.58"
      cores                 = 1
      memory_mb             = 4096
      root_disk_gb          = 40
      root_datastore_id     = "local-lvm"
      longhorn_data_disk_gb = null
      longhorn_datastore_id = null
    }
    k8s-worker-03 = {
      vm_id                 = 513
      proxmox_node          = "node-03"
      role                  = "worker"
      ip                    = "192.168.2.59"
      cores                 = 2
      memory_mb             = 10240
      root_disk_gb          = 40
      root_datastore_id     = "local-lvm"
      longhorn_data_disk_gb = 400
      longhorn_datastore_id = "longhorn-lvm"
    }
  }
}

resource "proxmox_storage_lvmthin" "longhorn" {
  id           = "longhorn-lvm"
  nodes        = ["node-02", "node-03"]
  volume_group = "vg-longhorn"
  thin_pool    = "longhorn"
  content      = ["images"]
}

resource "proxmox_virtual_environment_file" "cloud_init_user_data" {
  for_each     = local.cluster_nodes
  node_name    = each.value.proxmox_node
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

  name       = each.key
  node_name  = each.value.proxmox_node
  vm_id      = each.value.vm_id
  tags       = ["hemera", each.value.role]
  started    = true
  boot_order = ["virtio0"]

  clone {
    # Template 9000 is intentionally registered only on node-01.
    node_name = var.template_source_node
    vm_id     = var.nixos_template_id
    full      = true
  }

  agent { enabled = true }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory { dedicated = each.value.memory_mb }

  disk {
    datastore_id = each.value.root_datastore_id
    interface    = "virtio0"
    size         = each.value.root_disk_gb
  }

  dynamic "disk" {
    for_each = each.value.longhorn_data_disk_gb == null ? [] : [each.value.longhorn_data_disk_gb]
    content {
      datastore_id = each.value.longhorn_datastore_id
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
    datastore_id      = each.value.root_datastore_id
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

  lifecycle {
    # Clone/cloud-init metadata is only present at create time, and several VMs
    # were imported during the migration. Use explicit -replace for intentional
    # rebuilds instead of letting metadata drift replace live nodes unexpectedly.
    ignore_changes = [
      agent,
      clone,
      description,
      disk,
      initialization,
      keyboard_layout,
      scsi_hardware,
      serial_device,
    ]
  }

  depends_on = [proxmox_storage_lvmthin.longhorn]
}
