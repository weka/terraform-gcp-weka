variable "vpcs_to_peer_to_deployment_vpc" {
  type        = list(string)
  description = "list of vpcs name to peering"
}

variable "vpcs_name" {
  type        = list(string)
  description = "list of backend vpcs name"
}

variable "network_project_id" {
  type        = string
  default     = ""
  description = "Network project id"
}

variable "vpcs_range_to_peer_to_deployment_vpc" {
  type        = list(string)
  description = "list of vpcs range to peer"
  default     = []
}

variable "peering_name" {
  type        = string
  description = "Peering name. The name format will be <vpc1>-<peering_name>-<vpc2>"
  default = "peering"
}
