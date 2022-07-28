output "output-vpcs-names" {
  value =  length(var.vpcs) == 0 ? [for v in google_compute_network.vpc_network : v.name] : var.vpcs
}

output "output-gateway-address" {
  value =  length(var.subnets) == 0 ? [for g in google_compute_subnetwork.subnetwork: g.gateway_address ] : [ for g in data.google_compute_subnetwork.subnets_list_ids: g.gateway_address ]
}

output "output-subnetwork-name" {
  value = length(var.subnets) == 0 ? [for s in google_compute_subnetwork.subnetwork: s.name ] : [for s in data.google_compute_subnetwork.subnets_list_ids: s.name ]
}

output "output-subnets-range" {
  value = length(var.subnets) == 0 ? var.subnets-cidr-range : [ for i in data.google_compute_subnetwork.subnets_list_ids: i.ip_cidr_range ]
}

output "output-vpc-connector-name" {
  value = var.create_vpc_connector ? google_vpc_access_connector.connector[0].name : "projects/${var.project}/locations/${var.region}/connectors/${var.vpc_connector_name}"
}

output "output-private-zone-name" {
  value = google_dns_managed_zone.private-zone.name
}