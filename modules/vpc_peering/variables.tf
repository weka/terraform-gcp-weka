variable "vpcs_to_peer_to_deployment_vpc" {
  type        = list(string)
  description = "list of vpcs name to peering"
}

variable "vpcs_name" {
  type        = list(string)
  description = "list of backend vpcs name"
}
