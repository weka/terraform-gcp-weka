locals {
  peering_list_1 = flatten([
    for from in range(length(data.google_compute_network.vpcs.*.id)) : [
      for to in range(length(data.google_compute_network.vpc_to_peering.*.id)) : {
        from = data.google_compute_network.vpcs[from].self_link
        to   = data.google_compute_network.vpc_to_peering[to].self_link
        name = "${data.google_compute_network.vpcs[from].name}-peering-${data.google_compute_network.vpc_to_peering[to].name}"
      }
    ]
  ])
  peering_list_2 = flatten([
    for from in range(length(data.google_compute_network.vpc_to_peering.*.id)) : [
      for to in range(length(data.google_compute_network.vpcs.*.id)) : {
        from = data.google_compute_network.vpc_to_peering[from].self_link
        to   = data.google_compute_network.vpcs[to].self_link
        name = "${data.google_compute_network.vpc_to_peering[from].name}-peering-${data.google_compute_network.vpcs[to].name}"
      }
    ]
  ])
  tmp_vpcs_list = concat(local.peering_list_1, local.peering_list_2)
}

data "google_compute_network" "vpc_to_peering" {
  count   = length(var.vpcs_to_peer_to_deployment_vpc)
  project = var.vpc_to_peer_project_id
  name    = var.vpcs_to_peer_to_deployment_vpc[count.index]
}

data "google_compute_network" "vpcs" {
  count   = length(var.vpcs_name)
  project = var.project_id
  name    = var.vpcs_name[count.index]
}

resource "google_compute_network_peering" "peering" {
  count                               = length(local.tmp_vpcs_list)
  name                                = local.tmp_vpcs_list[count.index]["name"]
  network                             = local.tmp_vpcs_list[count.index]["to"]
  peer_network                        = local.tmp_vpcs_list[count.index]["from"]
  export_custom_routes                = true
  import_custom_routes                = true
  import_subnet_routes_with_public_ip = true
  lifecycle {
    ignore_changes = [network, peer_network]
  }
  depends_on = [data.google_compute_network.vpc_to_peering, data.google_compute_network.vpcs]
}

resource "google_compute_firewall" "ingress_sg" {
  count         = length(var.vpcs_name)
  name          = "${var.prefix}-allow-all-ingress-shared-sg-${count.index}"
  project       = var.project_id
  direction     = "INGRESS"
  network       = data.google_compute_network.vpcs[count.index].id
  source_ranges = var.vpcs_range_to_peer_to_deployment_vpc
  allow {
    protocol = "all"
  }
  source_tags = ["all"]

  lifecycle {
    ignore_changes = [network]
  }
}


resource "google_compute_firewall" "egress_sg" {
  count              = length(var.vpcs_name)
  name               = "${var.prefix}-allow-all-egress-shared-sg-${count.index}"
  project            = var.project_id
  direction          = "EGRESS"
  network            = data.google_compute_network.vpcs[count.index].id
  destination_ranges = var.vpcs_range_to_peer_to_deployment_vpc
  allow {
    protocol = "all"
  }
  lifecycle {
    ignore_changes = [network]
  }
}
