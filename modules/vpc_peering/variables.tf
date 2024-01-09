variable "project_id" {
  type        = string
  description = "project id"
}

variable "prefix" {
  type        = string
  description = "prefix for all resources"
  default     = "weka"
}

variable "vpcs_name" {
  type        = list(string)
  description = "list of vpcs name"
}

variable "vpcs_to_peer_to_deployment_vpc" {
  type        = list(string)
  description = "list of vpcs name to peer"
}

variable "vpcs_range_to_peer_to_deployment_vpc" {
  type        = list(string)
  description = "list of vpcs range to peer"
}

variable "vpc_to_peer_project_id" {
  description = "Shared vpc project id"
  type        = string
}
