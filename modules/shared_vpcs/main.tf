locals {
  vpc_length = length(var.shared_vpcs)
  peering_list = flatten([
  for from in range(length (var.vpcs)) : [
  for to in range(local.vpc_length) : {
    from = var.vpcs[from]
    to   = var.shared_vpcs[to]
  }
  ]
  ])
}


resource "google_project_iam_binding" "iam-binding" {
  project  = var.project
  role     = "roles/compute.networkAdmin"
  members  = ["serviceAccount:${var.sa_email}",]
}

resource "google_compute_shared_vpc_service_project" "service" {
  provider        = google.shared-vpc
  host_project    = var.host_project
  service_project = var.project
}


resource "google_compute_network_peering" "peering-service" {
  count                               = length(local.peering_list)
  name                                = "${local.peering_list[count.index]["from"]}-peering-${local.peering_list[count.index]["to"]}"
  network                             = "projects/${var.project}/global/networks/${local.peering_list[count.index]["from"]}"
  peer_network                        = "projects/${var.host_project}/global/networks/${local.peering_list[count.index]["to"]}"
  export_custom_routes                = true
  import_custom_routes                = true
  import_subnet_routes_with_public_ip = true
  depends_on                          = [google_compute_shared_vpc_service_project.service, google_project_iam_binding.iam-binding]
}

resource "google_compute_network_peering" "host-peering" {
  provider                            = google.shared-vpc
  count                               = length(local.peering_list)
  name                                = "${local.peering_list[count.index]["to"]}-peering-${local.peering_list[count.index]["from"]}"
  network                             = "projects/${var.host_project}/global/networks/${local.peering_list[count.index]["to"]}"
  peer_network                        = "projects/${var.project}/global/networks/${local.peering_list[count.index]["from"]}"
  export_custom_routes                = true
  import_custom_routes                = true
  import_subnet_routes_with_public_ip = true
  depends_on                          = [google_compute_shared_vpc_service_project.service, google_project_iam_binding.iam-binding, google_compute_network_peering.peering-service]
}

data "google_compute_network" "vpc_list_ids" {
  count    = length(var.vpcs)
  name     = var.vpcs[count.index]
  project  = var.project
}

resource "google_compute_firewall" "sg_private" {
  count         = length(var.vpcs)
  project       = var.project
  name          = "${var.prefix}-shared-sg-ingress-all-${count.index}"
  direction     = "INGRESS"
  network       = data.google_compute_network.vpc_list_ids[count.index].id
  source_ranges = var.host_shared_range
  allow {
    protocol = "all"
  }
  source_tags = ["all"]

  lifecycle {
    ignore_changes = [network]
  }
}


resource "google_compute_firewall" "sg_private_egress" {
  count               = length(var.vpcs)
  project             = var.project
  name                = "${var.prefix}-shared-sg-egress-all-${count.index}"
  direction           = "EGRESS"
  network             = data.google_compute_network.vpc_list_ids[count.index].id
  destination_ranges  = var.host_shared_range
  allow {
    protocol = "all"
  }

  lifecycle {
    ignore_changes = [network]
  }
}
