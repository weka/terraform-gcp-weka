locals {
  vpc_length = length(var.vpcs_list) == 0 ? var.vpc_number : length(var.vpcs_list)
  temp = flatten([
  for from in range(local.vpc_length) : [
  for to in range(local.vpc_length) : {
    from = from
    to   = to
  }
  ]
  ])
  peering-list = [for t in local.temp : t if t["from"] != t["to"]]
}

# ====================== vpc ==============================
resource "google_project_service" "project-compute" {
  project = var.project
  service = "compute.googleapis.com"
  disable_on_destroy = false
  disable_dependent_services = false
  depends_on = [google_project_service.project-gcp-api]
}

resource "google_project_service" "project-gcp-api" {
  project = var.project
  service = "iam.googleapis.com"
  disable_on_destroy = false
  disable_dependent_services = false
}

resource "google_project_service" "service-cloud-api" {
  project = var.project
  service = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
  disable_dependent_services = false
}

data "google_compute_network" "vpcs_lis_id" {
  count = length(var.vpcs_list)
  name  = var.vpcs_list[count.index]
}

resource "google_compute_network" "vpc_network" {
  count                   = length(var.vpcs_list) == 0 ? var.vpc_number :0
  name                    = "${var.prefix}-vpc-${count.index}"
  auto_create_subnetworks = false
  mtu                     = 1460

  depends_on = [google_project_service.project-compute, google_project_service.project-gcp-api]
}

# ======================= subnet ==========================
data google_compute_subnetwork "subnets-list-id"{
  count  =  length(var.subnets)
  name   = var.subnets[count.index]
  region = var.region
}

resource "google_compute_subnetwork" "subnetwork" {
  count         = length(var.subnets) == 0 ? var.vpc_number : 0
  name          = "${var.prefix}-subnet-${count.index}"
  ip_cidr_range = var.subnets_cidr_range[count.index]
  region        = var.region
  network       = length(var.vpcs_list) == 0 ? google_compute_network.vpc_network[count.index].name : var.vpcs_list[count.index]
  private_ip_google_access = true
}


resource "google_compute_network_peering" "peering" {
  count        = var.set_peering ? length(local.peering-list) : 0
  name         = "${var.prefix}-peering-${local.peering-list[count.index]["from"]}-${local.peering-list[count.index]["to"]}"
  network      = length(var.vpcs_list) == 0 ?  google_compute_network.vpc_network[local.peering-list[count.index]["from"]].self_link : data.google_compute_network.vpcs_lis_id[local.peering-list[count.index]["from"]].self_link #"https://www.googleapis.com/compute/v1/projects/${var.project}/global/networks/${var.vpcs_list[local.peering-list[count.index]["from"]]}"
  peer_network = length(var.vpcs_list) == 0 ?  google_compute_network.vpc_network[local.peering-list[count.index]["to"]].self_link : data.google_compute_network.vpcs_lis_id[local.peering-list[count.index]["to"]].self_link #"https://www.googleapis.com/compute/v1/projects/${var.project}/global/networks/${var.vpcs_list[local.peering-list[count.index]["to"]]}"

  depends_on = [google_compute_subnetwork.subnetwork]
}

# ========================= sg =================================
resource "google_compute_firewall" "sg_private" {
  count         = length(var.vpcs_list) == 0 ? length(google_compute_network.vpc_network) : length(var.vpcs_list)
  name          = "${var.prefix}-sg-all-${count.index}"
  network       = length(var.vpcs_list) == 0 ? google_compute_network.vpc_network[count.index].name : data.google_compute_network.vpcs_lis_id[count.index].name
  source_ranges = length(var.vpcs_list) == 0 ? google_compute_subnetwork.subnetwork.*.ip_cidr_range : [for s in data.google_compute_subnetwork.subnets-list-id: s.ip_cidr_range ]
  allow {
    protocol = "all"
  }
  source_tags = ["all"]
}

#================ Vpc connector ==========================

resource "google_vpc_access_connector" "connector" {
  count         = var.create_vpc_connector ? 1 : 0
  name          = "${var.prefix}-connector"
  ip_cidr_range = var.vpc_connector_range
  region        = var.region
  network       = length(var.vpcs_list) == 0 ? google_compute_network.vpc_network[0].id : data.google_compute_network.vpcs_lis_id[0].name #"projects/${var.project}/global/networks/${var.vpcs_list[0]}"
}

#============== Health check ============================
# allow all access from health check ranges
resource "google_compute_firewall" "fw_hc" {
  name          = "${var.prefix}-fw-allow-hc"
  direction     = "INGRESS"
  network       = length(var.vpcs_list) == 0 ? google_compute_network.vpc_network[0].self_link : data.google_compute_network.vpcs_lis_id[0].self_link #"projects/${var.project}/global/networks/${var.vpcs_list[0]}"
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16", "35.235.240.0/20"]
  allow {
    protocol = "tcp"
  }
  source_tags = ["allow-health-check"]
}

# allow communication within the subnet
resource "google_compute_firewall" "fw_ilb_to_backends" {
  name          = "${var.prefix}-fw-allow-ilb-to-backends"
  direction     = "INGRESS"
  network       = length(var.vpcs_list) == 0 ? google_compute_network.vpc_network[0].self_link : data.google_compute_network.vpcs_lis_id[0].self_link #"https://www.googleapis.com/compute/v1/projects/${var.project}/global/networks/${var.vpcs_list[0]}"
  source_ranges = length(var.vpcs_list) == 0 ? [var.subnets_cidr_range[0]] : [data.google_compute_subnetwork.subnets-list-id[0].ip_cidr_range]
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
}