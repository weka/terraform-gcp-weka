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
  count   = var.deploy_on_host_project ? 0 : 1
  project = var.project
  role    = "roles/compute.networkAdmin"
  members = ["serviceAccount:${var.sa_email}",]
}

resource "google_compute_shared_vpc_service_project" "service" {
  count           = var.deploy_on_host_project ? 1 : 0
  host_project    = var.project
  service_project = var.service_project
}


resource "google_compute_network_peering" "peering-service" {
  count        = var.deploy_on_host_project ? 0 : length(local.peering_list)
  name         = "${local.peering_list[count.index]["from"]}-peering-${local.peering_list[count.index]["to"]}"
  network      = "projects/${var.project}/global/networks/${local.peering_list[count.index]["from"]}"
  peer_network = "projects/${var.host_project}/global/networks/${local.peering_list[count.index]["to"]}"
  depends_on = [google_compute_shared_vpc_service_project.service]
}

resource "google_compute_network_peering" "host-peering" {
  count        = var.deploy_on_host_project ? length(local.peering_list) : 0
  name         = "${local.peering_list[count.index]["to"]}-peering-${local.peering_list[count.index]["from"]}"
  network      = "projects/${var.project}/global/networks/${local.peering_list[count.index]["to"]}"
  peer_network = "projects/${var.service_project}/global/networks/${local.peering_list[count.index]["from"]}"
  depends_on = [google_compute_shared_vpc_service_project.service]
}