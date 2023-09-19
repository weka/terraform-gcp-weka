variable "project_id" {
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
  default     = 4
}

variable "vpcs" {
  type        = list(string)
  description = "List of vpcs name"
  default     = []
}

variable "subnets_range" {
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

variable "allow_ssh_ranges" {
  type        = list(string)
  description = "list of ranges to allow ssh on public deployment"
}

variable "vpc_connector_region_map" {
  type        = map(string)
  description = "Map of region to use for vpc connector, as some regions do not have cloud functions enabled, and vpc connector needs to be in the same region"
  default     = {
    europe-west4       = "europe-west1"
    europe-north1      = "europe-west1",
    us-east5           = "us-east1",
    southamerica-west1 = "northamerica-northeast1",
    asia-south2        = "asia-south1",
  }
}

variable "private_zone_name" {
  type        = string
  description = "Private zone name"
  default     = ""
}

variable "private_dns_name" {
  type        = string
  description = "Private dns name"
  default     = ""
}

variable "mtu_size" {
  type        = number
  description = "mtu size"
  default     = 1460
}
