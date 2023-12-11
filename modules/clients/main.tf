data "google_compute_subnetwork" "this" {
  count   = length(var.subnets_list)
  name    = var.subnets_list[count.index]
  project = local.network_project_id
  region  = var.region
}

locals {
  network_project_id      = var.network_project_id != "" ? var.network_project_id : var.project_id
  private_nic_first_index = var.assign_public_ip ? 1 : 0
  preparation_script = templatefile("${path.module}/init.sh", {
    yum_repo_server = var.yum_repo_server
  })
  nics_num = var.frontend_container_cores_num + 1
  mount_wekafs_script = templatefile("${path.module}/mount_wekafs.sh", {
    all_subnets                  = split("\n", replace(join("\n", data.google_compute_subnetwork.this.*.ip_cidr_range), "/\\S+//", ""))[0]
    all_gateways                 = join(" ", data.google_compute_subnetwork.this.*.gateway_address)
    frontend_container_cores_num = var.frontend_container_cores_num
    backend_lb_ip                = var.backend_lb_ip
    mount_clients_dpdk           = var.clients_use_dpdk
    dpdk_base_memory_mb          = try(var.instance_config_overrides[var.machine_type].dpdk_base_memory_mb, 0)
  })

  custom_data_parts = [local.preparation_script, local.mount_wekafs_script]
  vms_custom_data   = join("\n", local.custom_data_parts)
}

resource "google_compute_disk" "this" {
  count = var.clients_number
  name  = "${var.clients_name}-disk-${count.index}"
  type  = "pd-standard"
  zone  = var.zone
  size  = var.disk_size
}

resource "google_compute_instance" "this" {
  count        = var.clients_number
  name         = "${var.clients_name}-${count.index}"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = [var.clients_name]
  boot_disk {
    initialize_params {
      image = var.source_image_id
    }
  }

  attached_disk {
    device_name = google_compute_disk.this[count.index].name
    mode        = "READ_WRITE"
    source      = google_compute_disk.this[count.index].self_link
  }

  # nic with public ip
  dynamic "network_interface" {
    for_each = range(local.private_nic_first_index)
    content {
      subnetwork_project = local.network_project_id
      subnetwork         = data.google_compute_subnetwork.this[network_interface.value].name
      access_config {}
    }
  }

  # nics with private ip
  dynamic "network_interface" {
    for_each = range(local.private_nic_first_index, local.nics_num)
    content {
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
    on_host_maintenance = try(var.instance_config_overrides[var.machine_type].host_maintenance, "MIGRATE")
  }
  lifecycle {
    ignore_changes = [network_interface, metadata_startup_script]
  }
  depends_on = [google_compute_disk.this]
}
