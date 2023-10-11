output "vpcs_names" {
  value       = length(var.vpcs) == 0 ? [for v in google_compute_network.vpc_network : v.name] : var.vpcs
  description = "List of vpcs names"
}

output "gateway_address" {
  value       = length(var.subnets) == 0 ? [for g in google_compute_subnetwork.subnetwork : g.gateway_address] : [for g in data.google_compute_subnetwork.subnets_list_ids : g.gateway_address]
  description = "List of vpcs gateway addresses"
}

output "subnetwork_name" {
  value       = length(var.subnets) == 0 ? [for s in google_compute_subnetwork.subnetwork : s.name] : [for s in data.google_compute_subnetwork.subnets_list_ids : s.name]
  description = "List of vpcs subnets names"
}

output "subnets_range" {
  value       = length(var.subnets) == 0 ? var.subnets_range : [for i in data.google_compute_subnetwork.subnets_list_ids : i.ip_cidr_range]
  description = "List of vpcs subnets ranges"
}

locals {
  vpc_connector_name = var.vpc_connector_name == "" ? google_vpc_access_connector.connector[0].name : var.vpc_connector_name
}

output "vpc_connector_name" {
  value       = "projects/${var.project_id}/locations/${lookup(var.vpc_connector_region_map, var.region, var.region)}/connectors/${local.vpc_connector_name}"
  description = "Vpc connector name"
}

output "private_zone_name" {
  value       = var.private_zone_name == "" ? google_dns_managed_zone.private_zone[0].name : var.private_zone_name
  description = "Private zone name"
}

output "private_dns_name" {
  value       = var.private_zone_name == "" ? google_dns_managed_zone.private_zone[0].dns_name : var.private_dns_name
  description = "Private zone dns name"
}
