output "output-vpcs-names" {
  value =  length(var.vpcs_list) == 0 ? [for v in google_compute_network.vpc_network : v.name] : [for v in data.google_compute_network.vpcs_lis_id: v.name ]
}

output "output-subnetwork-name" {
  value = length(var.subnets) == 0 ? [ for n in google_compute_subnetwork.subnetwork: n.name ] : [for s in data.google_compute_subnetwork.subnets-list-id: s.name ]
}

output "output-vpc-connector-name" {
  value = var.create_vpc_connector ? google_vpc_access_connector.connector[0].name : "projects/${var.project}/locations/${var.region}/connectors/${var.vpc_connector_name}"
}
