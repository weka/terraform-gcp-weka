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

resource "google_compute_instance_template" "backends-template" {
  name           = "${var.prefix}-${var.cluster_name}-backends"
  machine_type   = var.machine_type
  can_ip_forward = false

  tags = ["${var.prefix}-${var.cluster_name}-backends", "allow-health-check"]
  labels = {
    cluster_name = var.cluster_name
  }

  disk {
    source_image = data.google_compute_image.centos_7.id
    disk_size_gb = 50
    boot         = true
  }

  # nic with public ip
  network_interface {
    subnetwork = "https://www.googleapis.com/compute/v1/projects/${var.project}/regions/${var.region}/subnetworks/${var.subnets_name[0]}"
    access_config {}
  }

  # nics with private ip
  dynamic "network_interface" {
    for_each = range(1, var.nics_number)
     content {
      subnetwork = "https://www.googleapis.com/compute/v1/projects/${var.project}/regions/${var.region}/subnetworks/${var.subnets_name[network_interface.value]}"
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

  metadata = {
    ssh-keys = "${var.username}:${tls_private_key.ssh.public_key_openssh}"
  }


  metadata_startup_script = <<-EOT
    set -ex
    # https://gist.github.com/fungusakafungus/1026804
    function retry {
        local retry_max=$1
        local retry_sleep=$2
        shift 2
        local count=$retry_max
        while [ $count -gt 0 ]; do
            "$@" && break
            count=$(($count - 1))
            sleep $retry_sleep
        done
        [ $count -eq 0 ] && {
            echo "Retry failed [$retry_max]: $@"
            return 1
        }
        return 0
    }
  curl https://${var.region}-${var.project}.cloudfunctions.net/${var.prefix}-${var.cluster_name}-increment
  retry 300 2 curl --fail --max-time 10 https://${var.get_weka_io_token}@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}| sh
  curl https://${var.region}-${var.project}.cloudfunctions.net/${var.prefix}-${var.cluster_name}-bunch
 EOT
}

resource "google_compute_instance_template" "clusterize-template" {
  name           = "${var.prefix}-${var.cluster_name}-clusterize"
  machine_type   = var.machine_type
  can_ip_forward = false

  tags = ["${var.prefix}-${var.cluster_name}-backends"]
  labels = {
    cluster_name = var.cluster_name
  }

  disk {
    source_image = data.google_compute_image.centos_7.id
    disk_size_gb = 50
    boot         = true
  }

  # nic with public ip
  network_interface {
    subnetwork = "https://www.googleapis.com/compute/v1/projects/${var.project}/regions/${var.region}/subnetworks/${var.subnets_name[0]}"
    access_config {}
  }

  # nics with private ip
  dynamic "network_interface" {
    for_each = range(1, var.nics_number)
    content {
      subnetwork = "https://www.googleapis.com/compute/v1/projects/${var.project}/regions/${var.region}/subnetworks/${var.subnets_name[network_interface.value]}"
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

  metadata = {
    ssh-keys = "${var.username}:${tls_private_key.ssh.public_key_openssh}"
  }


  metadata_startup_script = <<-EOT
    set -ex
    # https://gist.github.com/fungusakafungus/1026804
    function retry {
        local retry_max=$1
        local retry_sleep=$2
        shift 2
        local count=$retry_max
        while [ $count -gt 0 ]; do
            "$@" && break
            count=$(($count - 1))
            sleep $retry_sleep
        done
        [ $count -eq 0 ] && {
            echo "Retry failed [$retry_max]: $@"
            return 1
        }
        return 0
    }
  curl https://${var.region}-${var.project}.cloudfunctions.net/${var.prefix}-${var.cluster_name}-increment
  retry 300 2 curl --fail --max-time 10 https://${var.get_weka_io_token}@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}| sh
  curl https://${var.region}-${var.project}.cloudfunctions.net/${var.prefix}-${var.cluster_name}-clusterize > /tmp/clusterize.sh
  chmod +x /tmp/clusterize.sh
  /tmp/clusterize.sh
  curl https://${var.region}-${var.project}.cloudfunctions.net/${var.prefix}-${var.cluster_name}-bunch
 EOT
}

resource "random_password" "password" {
  length  = 16
  lower   = true
  upper   = true
  numeric = true
  special = false
}

resource "google_compute_instance_template" "join-template" {
  name           = "${var.prefix}-${var.cluster_name}-join"
  machine_type   = var.machine_type
  can_ip_forward = false

  tags = ["${var.prefix}-${var.cluster_name}-backends"]
  labels = {
    cluster_name = var.cluster_name
  }

  disk {
    source_image = data.google_compute_image.centos_7.id
    disk_size_gb = 50
    boot         = true
  }

  # nic with public ip
  network_interface {
    subnetwork = "https://www.googleapis.com/compute/v1/projects/${var.project}/regions/${var.region}/subnetworks/${var.subnets_name[0]}"
    access_config {}
  }

  #nics with private ip
  dynamic "network_interface" {
    for_each = range(1, var.nics_number)
    content {
      subnetwork = "https://www.googleapis.com/compute/v1/projects/${var.project}/regions/${var.region}/subnetworks/${var.subnets_name[network_interface.value]}"
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

  metadata = {
    ssh-keys = "${var.username}:${tls_private_key.ssh.public_key_openssh}"
  }

  metadata_startup_script = <<-EOT
    set -ex
    curl https://${var.region}-${var.project}.cloudfunctions.net/${var.prefix}-${var.cluster_name}-increment
    curl https://${var.region}-${var.project}.cloudfunctions.net/${var.prefix}-${var.cluster_name}-join > /tmp/join.sh
    chmod +x /tmp/join.sh
    /tmp/join.sh
    curl https://${var.region}-${var.project}.cloudfunctions.net/${var.prefix}-${var.cluster_name}-bunch
 EOT
}

# ======================== instance-group ============================

resource "google_compute_instance_group" "instance_group" {
  name = "${var.prefix}-${var.cluster_name}-instance-group"
  zone = var.zone
  network = "https://www.googleapis.com/compute/v1/projects/${var.project}/global/networks/${var.vpcs[0]}"
}


# ======================== install-weka ============================

locals {
  gws_addresses = format("(%s)", join(" ", [for i in range(var.nics_number) : var.gateway_address_list[i] ]))
}

resource "null_resource" "write_weka_password_to_local_file" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "${random_password.password.result}" > weka_cluster_admin_password
    EOT
    interpreter = ["bash", "-ce"]
  }
}
