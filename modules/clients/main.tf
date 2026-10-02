data "google_compute_subnetwork" "this" {
  count   = length(var.subnets_list)
  name    = var.subnets_list[count.index]
  project = local.network_project_id
  region  = var.region
}

locals {
  # a specific reservation is pinned to one machine shape, so instances with no name of their own are
  # left with no affinity rather than pointed at another consumer's reservation
  reservation_affinity_type = (
    var.reservation_consume_type == "SPECIFIC_RESERVATION" && var.reservation_name == null
  ) ? null : var.reservation_consume_type

  network_project_id      = var.network_project_id != "" ? var.network_project_id : var.project_id
  private_nic_first_index = var.assign_public_ip ? 1 : 0
  preparation_script = templatefile("${path.module}/init.sh", {
    yum_repository_appstream_url = var.yum_repository_appstream_url
    yum_repository_baseos_url    = var.yum_repository_baseos_url
  })
  nics_num = var.clients_use_dpdk ? var.frontend_container_cores_num + 1 : 1
  mount_wekafs_script = templatefile("${path.module}/mount_wekafs.sh", {
    frontend_container_cores_num = var.frontend_container_cores_num
    backend_lb_ip                = var.backend_lb_ip
    clients_use_dpdk             = var.clients_use_dpdk
    dpdk_base_memory_mb          = try(var.instance_config_overrides[var.machine_type].dpdk_base_memory_mb, 0)
    weka_cgroups_mode            = var.weka_cgroups_mode
  })

  custom_data_parts = [local.preparation_script, local.mount_wekafs_script, "${var.custom_data}\n"]
  vms_custom_data   = join("\n", local.custom_data_parts)
}

resource "google_compute_instance" "this" {
  count             = var.clients_number
  name              = "${var.clients_name}-${count.index}"
  machine_type      = var.machine_type
  zone              = var.zone
  tags              = [var.clients_name]
  resource_policies = var.placement_policies
  boot_disk {
    initialize_params {
      image = var.source_image_id
      size  = var.root_volume_size
    }
  }

  # nic with public ip
  dynamic "network_interface" {
    for_each = range(local.private_nic_first_index)
    content {
      nic_type           = var.nic_type
      subnetwork_project = local.network_project_id
      subnetwork         = data.google_compute_subnetwork.this[network_interface.value].name
      access_config {}
    }
  }

  # nics with private ip
  dynamic "network_interface" {
    for_each = range(local.private_nic_first_index, local.nics_num)
    content {
      nic_type           = var.nic_type
      subnetwork_project = local.network_project_id
      subnetwork         = data.google_compute_subnetwork.this[network_interface.value].name
    }
  }

  metadata_startup_script = local.vms_custom_data

  metadata = {
    ssh-keys = "${var.vm_username}:${var.ssh_public_key}"
  }

  service_account {
    email  = var.sa_email
    scopes = ["cloud-platform"]
  }
  scheduling {
    # instances attached to a placement policy cannot live-migrate
    on_host_maintenance = length(var.placement_policies) > 0 ? "TERMINATE" : try(var.instance_config_overrides[var.machine_type].host_maintenance, "MIGRATE")
  }
  dynamic "reservation_affinity" {
    for_each = local.reservation_affinity_type == null ? [] : [1]
    content {
      type = local.reservation_affinity_type
      dynamic "specific_reservation" {
        for_each = local.reservation_affinity_type == "SPECIFIC_RESERVATION" ? [1] : []
        content {
          key    = "compute.googleapis.com/reservation-name"
          values = [var.reservation_name]
        }
      }
    }
  }
  labels = merge(var.labels_map, {
    goog-partner-solution = "isol_plb32_0014m00001h34hnqai_by7vmugtismizv6y46toim6jigajtrwh"
  })
  lifecycle {
    ignore_changes = [network_interface, metadata_startup_script]
  }
}
