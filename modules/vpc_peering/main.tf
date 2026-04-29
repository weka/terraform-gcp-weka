locals {
  peering_list_1 = [
    for to in range(length(data.google_compute_network.vpc_peering.*.id)) : {
      from = data.google_compute_network.vpc.self_link
      to   = data.google_compute_network.vpc_peering[to].self_link
      name = "${data.google_compute_network.vpc.name}-${var.peering_name}-${data.google_compute_network.vpc_peering[to].name}"
    }
  ]
  peering_list_2 = [
    for from in range(length(data.google_compute_network.vpc_peering.*.id)) : {
      from = data.google_compute_network.vpc_peering[from].self_link
      to   = data.google_compute_network.vpc.self_link
      name = "${data.google_compute_network.vpc_peering[from].name}-${var.peering_name}-${data.google_compute_network.vpc.name}"
    }
  ]
  tmp_vpcs_list = concat(local.peering_list_1, local.peering_list_2)
}

data "google_compute_network" "vpc_peering" {
  count   = length(var.vpcs_to_peer_to_deployment_vpc)
  project = var.network_project_id
  name    = var.vpcs_to_peer_to_deployment_vpc[count.index]
}

data "google_compute_network" "vpc" {
  project = var.network_project_id
  name    = var.vpc_name
}

resource "google_compute_network_peering" "peering" {
  count        = length(local.tmp_vpcs_list)
  name         = local.tmp_vpcs_list[count.index]["name"]
  network      = local.tmp_vpcs_list[count.index]["to"]
  peer_network = local.tmp_vpcs_list[count.index]["from"]
  lifecycle {
    ignore_changes = [network, peer_network]
  }
  depends_on = [data.google_compute_network.vpc_peering, data.google_compute_network.vpc]
}


resource "google_compute_firewall" "fw" {
  name          = "${var.vpc_name}-allow-peering-to-all-backends"
  provider      = google
  project       = var.network_project_id
  direction     = "INGRESS"
  network       = var.vpc_name
  source_ranges = var.vpcs_range_to_peer_to_deployment_vpc
  allow {
    protocol = "all"
  }
}
