output "vpcs-names-list" {
  value =  module.setup_network.output-vpcs-names
}

output "gateway-address-list" {
  value = module.setup_network.output-gateway-address
}

output "subnetwork-name-list" {
  value =  module.setup_network.output-subnetwork-name
}

output "subnets-range-list" {
  value = module.setup_network.output-subnets-range
}

output "service-account-email" {
  value = module.create_service_account.outputs-service-account-email
}
