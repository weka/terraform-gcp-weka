output "vpc_name" {
  value       = local.vpc_name
  description = "Vpc name"
}

output "vpc_self_link" {
  value       = one(google_compute_network.vpc_network.*.self_link)
  description = "VPC self-link"
}

output "gateway_address" {
  value       = length(var.subnets) == 0 ? length(var.subnets_range) > 0 ? [for g in google_compute_subnetwork.subnetwork : g.gateway_address] : [] : [for g in data.google_compute_subnetwork.subnets_list_ids : g.gateway_address]
  description = "List of subnets gateway addresses"
}

output "subnetwork_name" {
  value       = length(var.subnets) == 0 ? length(var.subnets_range) > 0 ? [for s in google_compute_subnetwork.subnetwork : s.name] : [] : [for s in data.google_compute_subnetwork.subnets_list_ids : s.name]
  description = "List of subnets names"
}

output "subnets_range" {
  value       = length(var.subnets) == 0 ? length(var.subnets_range) > 0 ? var.subnets_range : [] : [for i in data.google_compute_subnetwork.subnets_list_ids : i.ip_cidr_range]
  description = "List of subnets ranges"
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
