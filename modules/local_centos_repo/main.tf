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
  ip_cidr_range = var.public_cidr_range
  network       = google_compute_network.vpc_network.self_link
  region        = var.region
}

resource "google_compute_subnetwork" "private_subnet" {
  name          =  "global-private-net"
  project       = var.project
  ip_cidr_range = var.private_cidr_range
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
  source_ranges = [ var.public_cidr_range, var.private_cidr_range , var.vpc_range]
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

# ==================== yum repo vm ======================
data "google_compute_image" "centos_7" {
  family  = var.family_image
  project = var.project_image
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

  deletion_protection = true
  metadata_startup_script = file("${path.module}/setup_repo.sh")
}

data "google_compute_network" "vpcs_ids" {
  count   = length(var.vpcs_peering)
  name    = var.vpcs_peering[count.index]
  project = var.project
}

locals {
  temp = flatten([
  for from in range(length(var.vpcs_peering)) : [
  for to in range((1)) : {
    from = google_compute_network.vpc_network.name
    to   = var.vpcs_peering[from]
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
  count         = length(var.vpcs_peering)
  name          = "${var.vpcs_peering[count.index]}-sg-allow-global-vpc"
  network       = var.vpcs_peering[count.index]
  source_ranges = [var.public_cidr_range, var.private_cidr_range]
  project = var.project
  allow {
    protocol = "all"
  }
  source_tags = ["all"]
}


# =================== private DNS ==========================
locals {
  network_list = concat(formatlist(google_compute_network.vpc_network.id), [for v in data.google_compute_network.vpcs_ids: v.id ])
}

resource "google_project_service" "project-dns" {
  project = var.project
  service = "dns.googleapis.com"
  disable_on_destroy = false
  disable_dependent_services = false
}

resource "google_dns_managed_zone" "private-zone" {
  name        = "weka-private-zone"
  dns_name    = "weka.private.net."
  project     = var.project
  description = "private dns weka.private.net"
  visibility  = "private"

  private_visibility_config {
    dynamic "networks" {
      for_each = local.network_list
       content {
         network_url = networks.value
       }
    }
  }

  depends_on = [google_project_service.project-dns]
}

resource "google_dns_record_set" "record-a" {
  name         = "yum.${google_dns_managed_zone.private-zone.dns_name}"
  managed_zone = google_dns_managed_zone.private-zone.name
  project      = var.project
  type         = "A"
  ttl          = 120
  rrdatas      = [google_compute_instance.vm-repo.network_interface.0.network_ip]
}
