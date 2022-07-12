output "vpcs-names-list" {
  value =  module.setup_network.output-vpcs-names
}


output "subnetwork-name-list" {
  value =  module.setup_network.output-subnetwork-name
}

output "service-account-email" {
  value = module.create_service_account.outputs-service-account-email
}
