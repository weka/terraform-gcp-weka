variable "vpcs_to_peer_to_deployment_vpc" {
  type        = list(string)
  description = "The list of VPC names to peer to the deployment VPC."
}

variable "vpc_name" {
  type        = string
  description = "backend vpc name"
}

variable "network_project_id" {
  type        = string
  default     = ""
  description = "Network project id"
}

variable "vpcs_range_to_peer_to_deployment_vpc" {
  type        = list(string)
  description = "The list of VPC ranges to peer to the deployment VPC, in CIDR format."
  default     = []
}

variable "peering_name" {
  type        = string
  description = "Peering name. The name format will be <vpc1>-<peering_name>-<vpc2>"
  default     = "peering"
}
