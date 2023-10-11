# ======================== bucket ============================
resource "google_storage_bucket" "weka_deployment" {
  count                       = var.state_bucket_name == "" ? 1 : 0
  name                        = "${var.prefix}-${var.cluster_name}-${var.project_id}"
  location                    = var.region
  uniform_bucket_level_access = true
  lifecycle {
    precondition {
      condition     = length(var.prefix) + length(var.cluster_name) + length(var.project_id) <= 63
      error_message = "The bucket name maximum allowed length is 63."
    }
  }
}

# ======================== instances ============================
locals {
  private_nic_first_index = var.assign_public_ip ? 1 : 0
  nics_number             = var.nics_numbers != -1 ? var.nics_numbers : var.container_number_map[var.machine_type].nics
  disk_size               = var.default_disk_size + var.traces_per_ionode * (var.container_number_map[var.machine_type].compute + var.container_number_map[var.machine_type].drive + var.container_number_map[var.machine_type].frontend)
}

resource "google_compute_instance_template" "this" {
  name           = "${var.prefix}-${var.cluster_name}-backends"
  machine_type   = var.machine_type
  can_ip_forward = false

  tags = ["${var.prefix}-${var.cluster_name}-backends", "allow-health-check"]
  labels = {
    weka_cluster_name = var.cluster_name
  }
  service_account {
    email  = local.sa_email
    scopes = ["cloud-platform"]
  }
  disk {
    source_image = var.source_image_id
    disk_size_gb = 50
    boot         = true
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
      subnetwork = data.google_compute_subnetwork.this[network_interface.value].self_link
      access_config {}
    }
  }


  # nics with private ip
  dynamic "network_interface" {
    for_each = range(local.private_nic_first_index, local.nics_number)
    content {
      subnetwork = data.google_compute_subnetwork.this[network_interface.value].self_link
    }
  }
  disk {
    mode         = "READ_WRITE"
    disk_size_gb = 375
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${local.ssh_public_key}"
  }

  lifecycle {
    ignore_changes        = [network_interface]
    create_before_destroy = false
  }
  depends_on = [module.network] #time_sleep.wait_30_seconds
}

resource "random_password" "password" {
  length      = 16
  lower       = true
  min_lower   = 1
  upper       = true
  min_upper   = 1
  numeric     = true
  min_numeric = 1
  special     = false
}

# ======================== instance-group ============================

resource "google_compute_instance_group" "this" {
  name       = "${var.prefix}-${var.cluster_name}-instance-group"
  zone       = var.zone
  network    = data.google_compute_network.this[0].self_link
  project    = var.project_id
  depends_on = [google_compute_region_health_check.health_check, module.network]

  lifecycle {
    ignore_changes = [network]
  }
}

resource "null_resource" "terminate_cluster" {
  triggers = {
    command = <<EOT
      echo "Terminating cluster..."
      curl -m 70 -X POST ${format("%s%s", google_cloudfunctions2_function.cloud_internal_function.service_config[0].uri, "?action=terminate_cluster")} \
      -H "Authorization:bearer $(gcloud auth print-identity-token)" \
      -H "Content-Type:application/json" \
      -d '{"name":"${var.cluster_name}"}'
      EOT
  }
  provisioner "local-exec" {
    command = self.triggers.command
    when    = destroy
  }
  depends_on = [google_storage_bucket_object.state, google_cloudfunctions2_function.cloud_internal_function]
}
