provider "google" {
  alias   = "main"
  project = var.project
  region  = var.region
}

resource "google_compute_network" "vpc_network" {
  name                    = "global-${var.project}-vpc"
  auto_create_subnetworks = false
  mtu                     = 1460
  project                 = var.project
}

# ======================= subnet ==========================
resource "google_compute_subnetwork" "public_subnet" {
  name          =  "global-public-net"
  project       = var.project
  ip_cidr_range = var.pub_ip_cidr_range
  network       = google_compute_network.vpc_network.self_link
  region        = var.region
}
resource "google_compute_subnetwork" "private_subnet" {
  name          =  "global-private-net"
  project       = var.project
  ip_cidr_range = var.pri_ip_cidr_range
  network       = google_compute_network.vpc_network.self_link
  region        = var.region
}

# ==================== security group ====================
resource "google_compute_firewall" "allow-internal" {
  name    = "global-fw-allow-internal"
  project = var.project
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  source_ranges = [ var.pri_ip_cidr_range, var.pub_ip_cidr_range , var.vpc_range]
}

resource "google_compute_firewall" "allow-http" {
  name    = "global-fw-allow-http"
  project = var.project
  network = google_compute_network.vpc_network.name
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  target_tags = ["http"]
}

resource "google_compute_firewall" "allow-bastion" {
  name    = "global-fw-allow-bastion"
  project = var.project
  network = google_compute_network.vpc_network.name
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags = ["ssh"]
}

resource "google_compute_firewall" "egress-firewall-rules" {
  name          = "global-fw-egress-sg"
  network       = google_compute_network.vpc_network.name
  source_ranges = ["0.0.0.0/0"]
  project       = var.project
  direction = "EGRESS"
  allow {
    protocol = "all"
  }
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

# ==================== yum repo vm ======================
data "google_compute_image" "centos_7" {
  family  = "centos-7"
  project = "centos-cloud"
}

resource "google_compute_instance" "vm-repo" {
  name          = "weka-yum-repo"
  machine_type  = var.machine_type
  zone          =   var.zone
  tags          = ["ssh","http","webserver"]
  project       = var.project
  boot_disk {
    initialize_params {
      image = data.google_compute_image.centos_7.id
      size  = 100
    }
  }
  labels = {
    webserver =  "true"
  }
  network_interface {
    subnetwork = google_compute_subnetwork.public_subnet.self_link
    access_config {

    }
  }
  metadata = {
    ssh-keys = "${var.ssh_user}:${tls_private_key.ssh.public_key_openssh}"
  }
  deletion_protection = true
  metadata_startup_script = file("./setup_repo.sh")
  #resource_policies = [google_compute_resource_policy.scheduling-vm.id]

}

resource "google_storage_bucket_object" "upload-ssh-key" {
  name   = "weka-yum-repo-ssh-key"
  source = var.private_key_filename
  bucket = var.storage_bucket

  depends_on = [google_compute_instance.vm-repo]
}

data "google_compute_network" "vpcs_ids" {
  count   = length(var.vpcs-peering)
  name    = var.vpcs-peering[count.index]
  project = var.project
}

locals {
  temp = flatten([
  for from in range(length(var.vpcs-peering)) : [
  for to in range((1)) : {
    from = google_compute_network.vpc_network.name
    to   = var.vpcs-peering[from]
  }
  ]
  ])
  peering-list = [for t in local.temp : t if t["from"] != t["to"]]
}


resource "google_compute_network_peering" "peering-global" {
  count        = length(local.peering-list)
  name         = "global-peering-to-${local.peering-list[count.index]["to"]}"
  network      = "projects/${var.project}/global/networks/${local.peering-list[count.index]["from"]}"
  peer_network = "projects/${var.project}/global/networks/${local.peering-list[count.index]["to"]}"
}

resource "google_compute_network_peering" "peering-vpc" {
  count        = length(local.peering-list)
  name         = "${local.peering-list[count.index]["to"]}-peering-to-global"
  network      = "projects/${var.project}/global/networks/${local.peering-list[count.index]["to"]}"
  peer_network = "projects/${var.project}/global/networks/${local.peering-list[count.index]["from"]}"
}

resource "google_compute_firewall" "sg_private" {
  count         = length(var.vpcs-peering)
  name          = "${var.vpcs-peering[count.index]}-sg-allow-global-vpc"
  network       = var.vpcs-peering[count.index]
  source_ranges = [var.pub_ip_cidr_range, var.pri_ip_cidr_range]
  project = var.project
  allow {
    protocol = "all"
  }
  source_tags = ["all"]
}

