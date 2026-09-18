data "google_compute_subnetwork" "this" {
  count   = length(var.subnets_list)
  name    = var.subnets_list[count.index]
  project = local.network_project_id
  region  = var.region
}

locals {
  network_project_id      = var.network_project_id != "" ? var.network_project_id : var.project_id
  private_nic_first_index = var.assign_public_ip ? 1 : 0
  init_script = templatefile("${path.module}/init.sh", {
    yum_repository_appstream_url = var.yum_repository_appstream_url
    yum_repository_baseos_url    = var.yum_repository_baseos_url
    disk_size                    = var.weka_volume_size
    proxy_url                    = var.proxy_url
    deploy_function_url          = var.deploy_function_url
    report_function_url          = var.report_function_url
    protocol                     = "data"
  })
}

# ======================== instance ============================
resource "google_compute_instance_template" "this" {
  name                    = var.data_services_name
  region                  = var.region
  machine_type            = var.machine_type
  project                 = var.project_id
  tags                    = [var.data_services_name]
  metadata_startup_script = local.init_script

  labels = merge(var.labels_map, {
    weka_data_services    = var.data_services_name
    weka_hostgroup_type   = "data-services"
    goog-partner-solution = "isol_plb32_0014m00001h34hnqai_by7vmugtismizv6y46toim6jigajtrwh"
  })

  metadata = {
    ssh-keys = "${var.vm_username}:${var.ssh_public_key}"
  }

  disk {
    source_image = var.source_image_id
    auto_delete  = true
    disk_size_gb = var.root_volume_size
    boot         = true
  }

  disk {
    mode         = "READ_WRITE"
    disk_size_gb = var.weka_volume_size
    disk_type    = "pd-standard"
  }

  service_account {
    email  = var.sa_email
    scopes = ["cloud-platform"]
  }

  # nic with external ip
  dynamic "network_interface" {
    for_each = range(local.private_nic_first_index)
    content {
      subnetwork         = data.google_compute_subnetwork.this[network_interface.value].id
      subnetwork_project = local.network_project_id
      access_config {}
    }
  }
  # nic with private ip
  dynamic "network_interface" {
    for_each = range(local.private_nic_first_index, 1)
    content {
      subnetwork         = data.google_compute_subnetwork.this[network_interface.value].id
      subnetwork_project = local.network_project_id
    }
  }

  lifecycle {
    ignore_changes = [network_interface]
    precondition {
      condition     = var.data_services_number >= 1
      error_message = "The number of data services instances should be at least 1."
    }
    # the weka volume is located on the instance by its size, hence it must not match the root volume size
    precondition {
      condition     = var.root_volume_size == null ? true : var.root_volume_size != var.weka_volume_size
      error_message = "The data services root volume size must be different from the weka volume size."
    }
  }
}

resource "google_compute_instance_from_template" "this" {
  count                    = var.data_services_number
  name                     = "${var.data_services_name}-instance-${count.index}"
  zone                     = var.zone
  source_instance_template = google_compute_instance_template.this.self_link
  can_ip_forward           = false
  depends_on               = [google_compute_instance_template.this]
  labels = merge(var.labels_map, {
    goog-partner-solution = "isol_plb32_0014m00001h34hnqai_by7vmugtismizv6y46toim6jigajtrwh"
  })
  lifecycle {
    ignore_changes = all
  }
}
