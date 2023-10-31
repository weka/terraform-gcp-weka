locals {
  peering_list_1 = flatten([
    for from in range(length(data.google_compute_network.vpcs.*.id)) : [
      for to in range(length(data.google_compute_network.vpc_peering.*.id)) : {
        from = data.google_compute_network.vpcs[from].self_link
        to   = data.google_compute_network.vpc_peering[to].self_link
        name = "${data.google_compute_network.vpcs[from].name}-peering-${data.google_compute_network.vpc_peering[to].name}"
      }
    ]
  ])
  peering_list_2 = flatten([
    for from in range(length(data.google_compute_network.vpc_peering.*.id)) : [
      for to in range(length(data.google_compute_network.vpcs.*.id)) : {
        from = data.google_compute_network.vpc_peering[from].self_link
        to   = data.google_compute_network.vpcs[to].self_link
        name = "${data.google_compute_network.vpc_peering[from].name}-peering-${data.google_compute_network.vpcs[to].name}"
      }
    ]
  ])
  tmp_vpcs_list = concat(local.peering_list_1, local.peering_list_2)
}

data "google_compute_network" "vpc_peering" {
  count = length(var.vpcs_peering_list)
  name  = var.vpcs_peering_list[count.index]
}

data "google_compute_network" "vpcs" {
  count = length(var.vpcs_name)
  name  = var.vpcs_name[count.index]
}

resource "google_compute_network_peering" "peering" {
  count        = length(local.tmp_vpcs_list)
  name         = local.tmp_vpcs_list[count.index]["name"]
  network      = local.tmp_vpcs_list[count.index]["to"]
  peer_network = local.tmp_vpcs_list[count.index]["from"]
  depends_on   = [data.google_compute_network.vpc_peering, data.google_compute_network.vpcs]
}
