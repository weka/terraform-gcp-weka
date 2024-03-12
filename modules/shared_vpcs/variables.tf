variable "project_id" {
  type        = string
  description = "project id"
}

variable "prefix" {
  type        = string
  description = "prefix for all resources"
  default     = "weka"
}

variable "host_project" {
  type        = string
  description = "The ID of the project that will serve as a Shared VPC host project"
}

variable "shared_vpcs" {
  type        = list(string)
  description = "list of shared vpc name"
}

variable "vpcs_name" {
  type        = list(string)
  description = "list of vpcs name"
}

variable "host_shared_range" {
  type        = list(string)
  description = "list of host range to allow sg"
  default     = []
}

variable "set_shared_vpc_peering" {
  type    = bool
  default = false
}

variable "enable_shared_vpc_host_project" {
  description = "If this project is a shared VPC host project. If true, you must *not* set shared_vpc variable. Default is false."
  type        = bool
  default     = false
}

variable "shared_vpc_project_id" {
  description = "Shared vpc project id"
  type        = string
}

variable "peering_name" {
  type        = string
  description = "Peering name. The name format will be <vpc1>-<peering_name>-<vpc2>"
  default     = "peering"
}
