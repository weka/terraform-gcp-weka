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
}

variable "subnets-cidr-range" {
  type        = list(string)
  description = "list of subnets to use for creating the cluster, the number of subnets must be 'nics_number'"
}

variable "cluster_name" {
  type        = string
  description = "prefix cluster name for all resources"
}

variable "subnets" {
  type              = map(object({
    gateway-address = string
    vpc-name        = string
    cidr_range      = string
  }))
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
  default = ""
}