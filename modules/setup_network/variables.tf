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

variable "vpc_number" {
  type        = number
  description = "number of vpcs"
}

variable "vpcs_list" {
  type       = list(string)
  description = "List of vpcs name"
}

variable "subnets-cidr-range" {
  type        = list(string)
  description = "list of subnets to use for creating the cluster, the number of subnets must be 'nics_number'"
}

variable "subnets" {
  type   = list(string)
  description = "list of subnet name if existing"
}

variable "prefix" {
  type        = string
  description = "prefix for all resources"
}

variable "set_peering" {
  type = bool
  description = "apply peering connection between subnets and subnets "
}


variable "vpc_connector_range" {
  type        = string
  description = "list of connector to use for serverless vpc access"
}

variable "create_vpc_connector" {
  type = bool
  description = ""
}

variable "vpc_connector_name" {
  type = string
  description = ""
}