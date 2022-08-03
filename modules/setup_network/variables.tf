variable "project" {
  type        = string
  description = "project name"
}

variable "region" {
  type        = string
  description = "region name"
}

variable "zone" {
  type        = string
  description = "zone name"
}

variable "nics_number" {
  type        = number
  description = "number of nics per host"
}

variable "vpcs" {
  type       = list(string)
  description = "List of vpcs name"
  default = []
}

variable "subnets-cidr-range" {
  type        = list(string)
  description = "list of subnets to use for creating the cluster, the number of subnets must be 'nics_number'"
  default     = []
}

variable "subnets" {
  type = list(string)
  description = "List of subnets name"
  default = []
}

variable "prefix" {
  type        = string
  description = "prefix for all resources"
}

variable "set_peering" {
  type        = bool
  description = "apply peering connection between subnets and subnets "
  default     = true
}


variable "vpc_connector_range" {
  type        = string
  description = "list of connector to use for serverless vpc access"
  default     = ""
}

variable "create_vpc_connector" {
  type        = bool
  description = "Create vpc connector"
  default     = true
}

variable "vpc_connector_name" {
  type = string
  description = ""
  default = ""
}

variable "private_network" {
  type        = bool
  description = "deploy weka in private network"
}

variable "sg_public_ssh_cidr_range" {
  type        = list(string)
  description = "list of ranges to allow ssh on public deployment"
  default     = []
}