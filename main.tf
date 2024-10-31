# ======================== bucket ============================
resource "google_storage_bucket" "weka_deployment" {
  count                       = var.state_bucket_name == "" ? 1 : 0
  name                        = "${var.prefix}-${var.cluster_name}-${var.project_id}"
  location                    = var.region
  uniform_bucket_level_access = true
  labels = merge(var.labels_map, {
    goog-partner-solution = "isol_plb32_0014m00001h34hnqai_by7vmugtismizv6y46toim6jigajtrwh"
  })
  lifecycle {
    precondition {
      condition     = length(var.prefix) + length(var.cluster_name) + length(var.project_id) <= 63
      error_message = "The bucket name maximum allowed length is 63."
    }
  }
}

# ======================== instances ============================
locals {
  private_nic_first_index = local.assign_public_ip ? 1 : 0
  nics_number             = var.nic_number != -1 ? var.nic_number : var.containers_config_map[var.machine_type].nics
  disk_size               = var.default_disk_size + var.traces_per_ionode * (var.containers_config_map[var.machine_type].compute + var.containers_config_map[var.machine_type].drive + var.containers_config_map[var.machine_type].frontend)
}

resource "google_compute_instance_template" "this" {
  name           = "${var.prefix}-${var.cluster_name}-backends"
  machine_type   = var.machine_type
  can_ip_forward = false

  tags = ["${var.prefix}-${var.cluster_name}-backends", "allow-health-check", "backends", "all-apis"]
  labels = merge(var.labels_map, {
    weka_cluster_name     = var.cluster_name
    goog-partner-solution = "isol_plb32_0014m00001h34hnqai_by7vmugtismizv6y46toim6jigajtrwh"
  })
  service_account {
    email  = local.sa_email
    scopes = ["cloud-platform"]
  }
  disk {
    source_image = var.source_image_id
    boot         = true
    disk_type    = var.boot_disk_type
  }

  disk {
    device_name  = var.default_disk_name
    mode         = "READ_WRITE"
    disk_size_gb = local.disk_size
    disk_type    = "pd-ssd" # https://cloud.google.com/compute/docs/disks#disk-types
  }

  dynamic "disk" {
    for_each = range(var.nvmes_number)
    content {
      interface    = "NVME"
      boot         = false
      type         = "SCRATCH"
      disk_type    = "local-ssd"
      disk_size_gb = 375
    }
  }

  # nic with public ip
  dynamic "network_interface" {
    for_each = range(local.private_nic_first_index)
    content {
      nic_type           = var.nic_type
      subnetwork         = data.google_compute_subnetwork.this[network_interface.value].name
      subnetwork_project = local.network_project_id
      access_config {}
    }
  }


  # nics with private ip
  dynamic "network_interface" {
    for_each = range(local.private_nic_first_index, local.nics_number)
    content {
      nic_type           = var.nic_type
      subnetwork_project = local.network_project_id
      subnetwork         = data.google_compute_subnetwork.this[network_interface.value].name
    }
  }

  metadata = {
    ssh-keys = "${var.vm_username}:${local.ssh_public_key}"
  }

  lifecycle {
    ignore_changes        = [network_interface]
    create_before_destroy = false
  }
  depends_on = [module.network, module.shared_vpc_peering]
}

# ======================== instance-group ============================

resource "google_compute_instance_group" "this" {
  name       = "${var.prefix}-${var.cluster_name}-instance-group"
  zone       = var.zone
  network    = data.google_compute_network.this[0].self_link
  depends_on = [google_compute_region_health_check.health_check, module.network, module.shared_vpc_peering]
  lifecycle {
    ignore_changes = [network]
  }
}

resource "google_compute_instance_group" "nfs" {
  count      = var.nfs_setup_protocol ? 1 : 0
  name       = "${var.prefix}-${var.cluster_name}-nfs-group"
  zone       = var.zone
  network    = data.google_compute_network.this[0].self_link
  depends_on = [google_compute_region_health_check.health_check, module.network, module.shared_vpc_peering]
  lifecycle {
    ignore_changes = [network]
  }
}
