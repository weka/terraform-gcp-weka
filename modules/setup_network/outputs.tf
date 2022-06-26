output "output-vpcs-names" {
  value =  length(var.vpcs) == 0 ? [for v in google_compute_network.vpc_network : v.name] : var.vpcs
}

output "output-gateway-address" {
  value =  length(var.subnets) == 0 ? [for g in google_compute_subnetwork.subnetwork: g.gateway_address ] : [ for n in var.subnets : n["gateway-address"]]
}

output "output-subnetwork-name" {
  value = length(var.subnets) == 0 ? [ for n in google_compute_subnetwork.subnetwork: n.name ] : [for k,v  in var.subnets: k ]
}

output "output-subnets-range" {
  value = length(var.subnets) == 0 ? var.subnets-cidr-range : [ for s in var.subnets: s["cidr_range"] ]
}

output "output-vpc-connector-name" {
  value = var.create_vpc_connector ? google_vpc_access_connector.connector[0].name : var.vpc_connector_name
}
