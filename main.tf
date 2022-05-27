resource "google_compute_network" "vpc_network" {
  count                   = var.cluster_size
  name                    = "${var.prefix}-vpc-${count.index}"
  auto_create_subnetworks = false
  mtu                     = 1460
}

# ======================= subnet ==========================
resource "google_compute_subnetwork" "subnetwork" {
  count         = length(google_compute_network.vpc_network)
  name          = "${var.prefix}-subnet-${count.index}"
  ip_cidr_range = "10.${count.index}.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network[count.index].name
}

resource "google_compute_network_peering" "peering-0" {
  for_each     = toset(["1", "2", "3", "4"])
  name         = "peering-0-${each.key}"
  network      = google_compute_network.vpc_network[0].self_link
  peer_network = google_compute_network.vpc_network[tonumber(each.key)].self_link
}

resource "google_compute_network_peering" "peering-1" {
  for_each     = toset(["0", "2", "3", "4"])
  name         = "peering-1-${each.key}"
  network      = google_compute_network.vpc_network[1].self_link
  peer_network = google_compute_network.vpc_network[tonumber(each.key)].self_link
}

resource "google_compute_network_peering" "peering-2" {
  for_each     = toset(["0", "1", "3", "4"])
  name         = "peering-2-${each.key}"
  network      = google_compute_network.vpc_network[2].self_link
  peer_network = google_compute_network.vpc_network[tonumber(each.key)].self_link
}

resource "google_compute_network_peering" "peering-3" {
  for_each     = toset(["0", "1", "2", "4"])
  name         = "peering-3-${each.key}"
  network      = google_compute_network.vpc_network[3].self_link
  peer_network = google_compute_network.vpc_network[tonumber(each.key)].self_link
}
resource "google_compute_network_peering" "peering-4" {
  for_each     = toset(["0", "1", "2", "3"])
  name         = "peering-4-${each.key}"
  network      = google_compute_network.vpc_network[4].self_link
  peer_network = google_compute_network.vpc_network[tonumber(each.key)].self_link
}

# ======================== ssh-key ============================
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "ssh_private_key_pem" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = ".ssh/google_compute_engine"
  file_permission = "0600"
}

resource "google_compute_firewall" "sg" {
  count         = length(google_compute_network.vpc_network)
  name          = "ssh-${count.index}"
  network       = google_compute_network.vpc_network[count.index].name
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_tags   = ["ssh"]
}

resource "google_compute_firewall" "sg_private" {
  count         = length(google_compute_network.vpc_network)
  name          = "all-${count.index}"
  network       = google_compute_network.vpc_network[count.index].name
  source_ranges = ["10.0.0.0/8"]
  allow {
    protocol = "all"
  }
  source_tags   = ["all"]
}


# ======================== instance ============================
resource "google_compute_instance" "compute" {
  count        = length(google_compute_network.vpc_network)
  name         = "${var.prefix}-compute-${count.index}"
  machine_type = "c2-standard-16"
  zone         = "${var.region}-a"
  tags         = ["${var.prefix}-compute"]

  metadata = {
    ssh-keys = "${var.username}:${tls_private_key.ssh.public_key_openssh}"
  }

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
      size = 50
    }
  }

  dynamic "scratch_disk" {
    for_each = range(var.nvmes_number)
    content {
      interface = "NVME"
    }
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

  metadata_startup_script = "curl https://${var.get_weka_io_token}@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}| sh"
}

resource "null_resource" "generate_script_env_vars" {
  provisioner "local-exec" {
    command = <<-EOT
      IPS=$(echo ${IPS} | tr -d '\n')
      GWS=$(echo ${GWS} | tr -d '\n')
      echo "IPS=($IPS)"
      echo "GWS=($GWS)"
      echo "HOSTS_NUM=$HOSTS_NUM"
      echo "GWS_NUM=$GWS_NUM"
      echo "CLUSTER_NAME=$CLUSTER_NAME"
      echo "NVMES_NUM=$NVMES_NUM"
    EOT
    interpreter = ["bash", "-ce"]
    environment = {
      IPS = <<-EOT
        %{ for i in range(var.cluster_size) }
          %{ for j in range(var.nics_number) }
              ${google_compute_instance.compute[i].network_interface[j].network_ip}
          %{ endfor ~}
        %{ endfor ~}
      EOT
      HOSTS_NUM = var.cluster_size
      GWS_NUM = var.nics_number
      GWS = <<-EOT
        %{ for i in range(var.nics_number) }
            ${google_compute_subnetwork.subnetwork[i].gateway_address}
        %{ endfor ~}
      EOT
      CLUSTER_NAME=var.cluster_name
      NVMES_NUM=var.nvmes_number
    }
  }
}
