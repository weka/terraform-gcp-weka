locals {
  vpc_length = length(var.shared_vpcs)
  peering_list = flatten([
    for from in range(length(var.vpcs_name)) : [
      for to in range(local.vpc_length) : {
        from = var.vpcs_name[from]
        to   = var.shared_vpcs[to]
      }
    ]
  ])
}

resource "google_compute_shared_vpc_host_project" "shared_vpc_host" {
  count   = var.enable_shared_vpc_host_project ? 1 : 0
  project = var.host_project
}

resource "google_compute_shared_vpc_service_project" "shared_vpc_service" {
  count           = var.enable_shared_vpc_host_project ? 1 : 0
  host_project    = var.host_project
  service_project = var.project_id
  depends_on      = [google_compute_shared_vpc_host_project.shared_vpc_host]
}

resource "google_compute_network_peering" "peering_service" {
  count                               = var.set_shared_vpc_peering ? length(local.peering_list) : 0
  name                                = "${local.peering_list[count.index]["from"]}-${var.peering_name}-${local.peering_list[count.index]["to"]}"
  network                             = "projects/${var.project_id}/global/networks/${local.peering_list[count.index]["from"]}"
  peer_network                        = "projects/${var.shared_vpc_project_id}/global/networks/${local.peering_list[count.index]["to"]}"
  export_custom_routes                = true
  import_custom_routes                = true
  import_subnet_routes_with_public_ip = true
  depends_on                          = [google_compute_shared_vpc_service_project.shared_vpc_service] #, google_project_iam_binding.iam_binding]
}

resource "google_compute_network_peering" "host_peering" {
  count                               = var.set_shared_vpc_peering ? length(local.peering_list) : 0
  name                                = "${local.peering_list[count.index]["to"]}-${var.peering_name}-${local.peering_list[count.index]["from"]}"
  network                             = "projects/${var.shared_vpc_project_id}/global/networks/${local.peering_list[count.index]["to"]}"
  peer_network                        = "projects/${var.project_id}/global/networks/${local.peering_list[count.index]["from"]}"
  export_custom_routes                = true
  import_custom_routes                = true
  import_subnet_routes_with_public_ip = true
  depends_on                          = [google_compute_shared_vpc_service_project.shared_vpc_service, google_compute_network_peering.peering_service] #google_project_iam_binding.iam_binding,
}

data "google_compute_network" "vpc_list_ids" {
  count   = length(var.vpcs_name)
  project = var.project_id
  name    = var.vpcs_name[count.index]
}

resource "google_compute_firewall" "sg_private" {
  count         = var.set_shared_vpc_peering ? length(var.vpcs_name) : 0
  name          = "${var.prefix}-shared-sg-ingress-all-${count.index}"
  project       = var.project_id
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
  count              = var.set_shared_vpc_peering ? length(var.vpcs_name) : 0
  name               = "${var.prefix}-shared-sg-egress-all-${count.index}"
  project            = var.project_id
  direction          = "EGRESS"
  network            = data.google_compute_network.vpc_list_ids[count.index].id
  destination_ranges = var.host_shared_range
  allow {
    protocol = "all"
  }

  lifecycle {
    ignore_changes = [network]
  }
}
