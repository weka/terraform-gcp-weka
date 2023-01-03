variable "project" {
  type        = string
  description = "project id"
}

variable "region" {
  type        = string
  description = "region name"
}

variable "zone" {
  type        = string
  description = "zone name"
}

variable "vpcs_number" {
  type        = number
  description = "number of vpcs"
  default = 4
}

variable "vpcs" {
  type        = list(string)
  description = "List of vpcs name"
  default     = []
}

variable "subnets-cidr-range" {
  type        = list(string)
  description = "list of subnets to use for creating the cluster, the number of subnets must be 'vpcs_number'"
  default     = []
}

variable "subnets" {
  type        = list(string)
  description = "List of subnets name"
  default     = []
}

variable "prefix" {
  type        = string
  description = "prefix for all resources"
  default     = "weka"
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

variable "vpc_connector_name" {
  type        = string
  description = "exiting vpc connector name to use for cloud functions"
  default     = ""
}

variable "private_network" {
  type        = bool
  description = "deploy weka in private network"
  default     = false
}

variable "sg_public_ssh_cidr_range" {
  type        = list(string)
  description = "list of ranges to allow ssh on public deployment"
  default     = ["0.0.0.0/0"]
}

variable "vpc_connector_region_map" {
  type        = map(string)
  description = "Map of region to use for vpc connector, as some regions do not have cloud functions enabled, and vpc connector needs to be in the same region"
  default     = {
    europe-west4 = "europe-west1"
  }
}
