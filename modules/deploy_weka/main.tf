# ======================== ssh-key ============================
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "ssh_private_key_pem" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = var.private_key_filename
  file_permission = "0600"
}

# ======================== instances ============================

data "google_compute_image" "centos_7" {
  family  = "centos-7"
  project = "centos-cloud"
}

data "google_compute_subnetwork" "subnets_ids" {
  count = length(var.subnets_list)
  name = var.subnets_list[count.index]
}


resource "google_compute_instance_template" "backends-template" {
  name           = "${var.prefix}-${var.cluster_name}-backends"
  machine_type   = var.machine_type
  can_ip_forward = false

  tags = ["${var.prefix}-${var.cluster_name}-backends", "allow-health-check"]
  labels = {
    cluster_name = var.cluster_name
  }
  service_account {
    email = var.sa_email
    scopes = ["cloud-platform"]
  }
  disk {
    source_image = data.google_compute_image.centos_7.id
    disk_size_gb = 50
    boot         = true
  }
  # nic with public ip
  network_interface {
    subnetwork = data.google_compute_subnetwork.subnets_ids[0].self_link
    access_config {}
  }

  # nics with private ip
  dynamic "network_interface" {
    for_each = range(1, var.nics_number)
     content {
      subnetwork = data.google_compute_subnetwork.subnets_ids[network_interface.value].self_link
    }
 }

  metadata = {
    ssh-keys = "${var.username}:${tls_private_key.ssh.public_key_openssh}"
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


  metadata_startup_script = <<-EOT
  mkdir /tmp/yum.repos.d
  mv /etc/yum.repos.d/*.repo /tmp/yum.repos.d/

  cat >/etc/yum.repos.d/local.repo <<EOL
  [local]
  name=Centos Base
  baseurl=${var.yum_repo_server}
  enabled=1
  gpgcheck=0
  EOL

  curl https://${var.region}-${var.project}.cloudfunctions.net/${var.prefix}-${var.cluster_name}-deploy -H "Authorization:bearer $(gcloud auth print-identity-token)" > /tmp/deploy.sh
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

data "google_compute_network" "vpcs_lis_id" {
  count = length(var.vpcs_list)
  name  = var.vpcs_list[count.index]
}

resource "google_compute_instance_group" "instance_group" {
  name = "${var.prefix}-${var.cluster_name}-instance-group"
  zone = var.zone
  network = data.google_compute_network.vpcs_lis_id[0].self_link
}


# ======================== install-weka ============================
locals {
  gws_addresses = format("(%s)", join(" ", [for i in range(var.nics_number) : data.google_compute_subnetwork.subnets_ids[i].gateway_address ]))
}

resource "null_resource" "write_weka_password_to_local_file" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "${random_password.password.result}" > weka_cluster_admin_password
    EOT
    interpreter = ["bash", "-ce"]
  }
}
