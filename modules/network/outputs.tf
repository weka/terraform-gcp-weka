output "vpcs_names" {
  value       = length(var.vpcs) == 0 ? [for v in google_compute_network.vpc_network : v.name] : var.vpcs
  description = "List of vpcs names"
}

output "vpc_self_links" {
  value       = [for v in google_compute_network.vpc_network : v.self_link]
  description = "List of VPC self-links"
}

output "gateway_address" {
  value       = length(var.subnets) == 0 ? length(var.subnets_range) > 0 ? [google_compute_subnetwork.subnetwork[0].gateway_address] : [] : [data.google_compute_subnetwork.subnets_list_ids[0].gateway_address]
  description = "List of vpcs gateway addresses"
}

output "subnetwork_name" {
  value       = length(var.subnets) == 0 ? length(var.subnets_range) > 0 ? [google_compute_subnetwork.subnetwork[0].name] : [] : [data.google_compute_subnetwork.subnets_list_ids[0].name]
  description = "Subnet name"
}

output "subnets_range" {
  value       = length(var.subnets) == 0 ? length(var.subnets_range) > 0 ? var.subnets_range : [] : [data.google_compute_subnetwork.subnets_list_ids[0].ip_cidr_range]
  description = "Subnet range"
}

output "vpc_connector_id" {
  value       = var.vpc_connector_id == "" && var.vpc_connector_range != "" ? google_vpc_access_connector.connector[0].id : ""
  description = "Vpc connector id"
}

output "private_zone_name" {
  value       = var.private_zone_name == "" ? google_dns_managed_zone.private_zone[0].name : var.private_zone_name
  description = "Private zone name"
}

output "private_dns_name" {
  value       = var.private_zone_name == "" ? google_dns_managed_zone.private_zone[0].dns_name : var.private_dns_name
  description = "Private zone dns name"
}
