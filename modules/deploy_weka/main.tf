# ======================== bucket ============================
resource "google_storage_bucket" "weka_deployment" {
  name     = "${var.prefix}-${var.cluster_name}-${var.project}"
  location = var.internal_bucket_location
}

# ======================== instances ============================
locals {
  private_nic_first_index = var.private_network ? 0 : 1
}

data "google_compute_network" "vpc_list_ids"{
  count = length(var.vpcs)
  name  = var.vpcs[count.index]
}

data "google_compute_subnetwork" "subnets_list_ids" {
  count  = length(var.subnets_name)
  name   = var.subnets_name[count.index]
}

resource "google_compute_instance_template" "backends-template" {
  name           = "${var.prefix}-${var.cluster_name}-backends"
  machine_type   = var.machine_type
  can_ip_forward = false

  tags = ["${var.prefix}-${var.cluster_name}-backends", "allow-health-check"]
  labels = {
    weka_cluster_name = var.cluster_name
  }
  service_account {
    email = google_service_account.internal-sa.email
    scopes = ["cloud-platform"]
  }
  disk {
    source_image = var.weka_image_id
    disk_size_gb = 50
    boot         = true
  }

  # nic with public ip
  dynamic "network_interface" {
    for_each = range(local.private_nic_first_index)
    content {
      subnetwork = data.google_compute_subnetwork.subnets_list_ids[network_interface.value].self_link
      access_config {}
    }
  }


# nics with private ip
  dynamic "network_interface" {
    for_each = range(local.private_nic_first_index, var.nics_number)
     content {
      subnetwork = data.google_compute_subnetwork.subnets_list_ids[network_interface.value].self_link
    }
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

  lifecycle {
    ignore_changes = [network_interface]
  }

  metadata_startup_script = <<-EOT
  if [ "${var.yum_repo_server}" ] ; then
    mkdir /tmp/yum.repos.d
    mv /etc/yum.repos.d/*.repo /tmp/yum.repos.d/

    cat >/etc/yum.repos.d/local.repo <<EOL
  [local]
  name=Centos Base
  baseurl=${var.yum_repo_server}
  enabled=1
  gpgcheck=0
  EOL
  fi

  curl ${google_cloudfunctions2_function.deploy_function.service_config[0].uri} -H "Authorization:bearer $(gcloud auth print-identity-token)" > /tmp/deploy.sh
  chmod +x /tmp/deploy.sh
  /tmp/deploy.sh
 EOT
}

resource "random_password" "password" {
  length  = 16
  lower   = true
  min_lower = 1
  upper   = true
  min_upper = 1
  numeric = true
  min_numeric = 1
  special = false
}

# ======================== instance-group ============================

resource "google_compute_instance_group" "instance_group" {
  name = "${var.prefix}-${var.cluster_name}-instance-group"
  zone = var.zone
  network = data.google_compute_network.vpc_list_ids[0].self_link
  project = "${var.project}"
  depends_on = [google_compute_region_health_check.health_check]

  lifecycle {
    ignore_changes = [network]
  }
}
