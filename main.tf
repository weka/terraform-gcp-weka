resource "google_compute_network" "vpc_network" {
  count                   = var.nics_number
  name                    = "${var.prefix}-vpc-${count.index}"
  auto_create_subnetworks = false
  mtu                     = 1460
}

# ======================= subnet ==========================
locals {
  temp = flatten([
  for from in range(length(google_compute_network.vpc_network)) : [
  for to in range(length(google_compute_network.vpc_network)) : {
    from = from
    to   = to
  }
  ]
  ])
  peering-list = [for t in local.temp : t if t["from"] != t["to"]]
}

resource "google_compute_subnetwork" "subnetwork" {
  count         = length(google_compute_network.vpc_network)
  name          = "${var.prefix}-subnet-${count.index}"
  ip_cidr_range = var.subnets[count.index]
  region        = var.region
  network       = google_compute_network.vpc_network[count.index].name
}

resource "google_compute_network_peering" "peering" {
  count        = length(local.peering-list)
  name         = "${var.prefix}-peering-${local.peering-list[count.index]["from"]}-${local.peering-list[count.index]["to"]}"
  network      = google_compute_network.vpc_network[local.peering-list[count.index]["from"]].self_link
  peer_network = google_compute_network.vpc_network[local.peering-list[count.index]["to"]].self_link
}

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

resource "google_compute_firewall" "sg" {
  count         = length(google_compute_network.vpc_network)
  name          = "${var.prefix}-sg-ssh-${count.index}"
  network       = google_compute_network.vpc_network[count.index].name
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_tags = ["ssh"]
}

resource "google_compute_firewall" "sg_private" {
  count         = length(google_compute_network.vpc_network)
  name          = "${var.prefix}-ag-all-${count.index}"
  network       = google_compute_network.vpc_network[count.index].name
  source_ranges = ["10.0.0.0/8"]
  allow {
    protocol = "all"
  }
  source_tags = ["all"]
}

# ======================== instances ============================
data "google_compute_image" "centos_7" {
  family  = "centos-7"
  project = "centos-cloud"
}

resource "google_compute_instance_template" "backends-template" {
  name           = "${var.prefix}-backends"
  machine_type   = var.machine_type
  can_ip_forward = false

  tags = ["${var.prefix}-backends"]
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
    subnetwork = google_compute_subnetwork.subnetwork[0].name
    access_config {}
  }

  # nics with private ip
  dynamic "network_interface" {
    for_each = range(1, var.nics_number)
    content {
      subnetwork = google_compute_subnetwork.subnetwork[network_interface.value].name
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

  retry 300 2 curl --fail --max-time 10 https://${var.get_weka_io_token}@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}| sh
  curl https://europe-west1-wekaio-rnd.cloudfunctions.net/increment
 EOT
}

resource "google_compute_instance_template" "clusterize-template" {
  name           = "${var.prefix}-clusterize"
  machine_type   = var.machine_type
  can_ip_forward = false

  tags = ["${var.prefix}-backends"]
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
    subnetwork = google_compute_subnetwork.subnetwork[0].name
    access_config {}
  }

  # nics with private ip
  dynamic "network_interface" {
    for_each = range(1, var.nics_number)
    content {
      subnetwork = google_compute_subnetwork.subnetwork[network_interface.value].name
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

  retry 300 2 curl --fail --max-time 10 https://${var.get_weka_io_token}@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}| sh

  curl https://${var.region}-${var.project}.cloudfunctions.net/clusterize > /tmp/clusterize.sh
  chmod +x /tmp/clusterize.sh
  /tmp/clusterize.sh
 EOT
}

resource "random_password" "password" {
  length           = 16
  lower = true
  upper = true
  numeric = true
  special = false
}

resource "google_compute_instance_template" "join-template" {
  name           = "${var.prefix}-join"
  machine_type   = var.machine_type
  can_ip_forward = false

  tags = ["${var.prefix}-backends"]
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
    subnetwork = google_compute_subnetwork.subnetwork[0].name
    access_config {}
  }

  # nics with private ip
  dynamic "network_interface" {
    for_each = range(1, var.nics_number)
    content {
      subnetwork = google_compute_subnetwork.subnetwork[network_interface.value].name
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
    curl https://${var.region}-${var.project}.cloudfunctions.net/join > /tmp/join.sh
    chmod +x /tmp/join.sh
    /tmp/join.sh
 EOT
}


# ======================== instance-group ============================
resource "google_compute_target_pool" "target_pool" {
  name = "${var.prefix}-target-pool"
}

resource "google_compute_instance_group" "instance_group" {
  name = "${var.prefix}-instance-group"
  zone = var.zone
}

# ======================== install-weka ============================

locals {
  gws_addresses = format("(%s)", join(" ", [for i in range(var.nics_number) : google_compute_subnetwork.subnetwork[i].gateway_address]))
}

resource "null_resource" "write_weka_password_to_local_file" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "${random_password.password.result}" > weka_cluster_admin_password
    EOT
    interpreter = ["bash", "-ce"]
  }
}


#================ Vpc connector ==========================
resource "google_project_service" "vpc-access-api" {
  project = var.project
  service = "vpcaccess.googleapis.com"
  disable_on_destroy = false
}


resource "google_vpc_access_connector" "connector" {
  name          = "${var.prefix}-vpc-connector"
  ip_cidr_range = var.connector
  network       = google_compute_network.vpc_network[0].name
  depends_on = [google_project_service.vpc-access-api, google_compute_network.vpc_network]
}
