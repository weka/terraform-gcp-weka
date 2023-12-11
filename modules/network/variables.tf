variable "project_id" {
  type        = string
  description = "project id"
}

variable "region" {
  type        = string
  description = "region name"
}

variable "vpcs" {
  type        = list(string)
  description = "List of vpcs name"
  default     = []
  validation {
    condition     = length(var.vpcs) == 0 || length(var.vpcs) == 4 || length(var.vpcs) == 7
    error_message = "The allowed amount of vpcs are 0, 4 and 7"
  }
}

variable "subnets_range" {
  type        = list(string)
  description = "list of subnets to use for creating the cluster, the number of subnets must be 'vpcs_number'"
  default     = []
  validation {
    condition     = length(var.subnets_range) == 0 || length(var.subnets_range) == 4 || length(var.subnets_range) == 7
    error_message = "The allowed amount of subnet ranges are 0, 4 and 7"
  }
}

variable "subnets" {
  type        = list(string)
  description = "List of subnets name"
  default     = []
  validation {
    condition     = length(var.subnets) == 0 || length(var.subnets) == 4 || length(var.subnets) == 7
    error_message = "The allowed amount of subnets are 0, 4 and 7"
  }
}

variable "psc_subnet_cidr" {
  type        = string
  default     = "10.9.0.0/28"
  description = "Cidr range for private service connection subnet"
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

variable "vpc_connector_id" {
  type        = string
  description = "exiting vpc connector id to use for cloud functions"
  default     = ""
}

variable "allow_ssh_cidrs" {
  type        = list(string)
  description = "Allow port 22, if not provided, i.e leaving the default empty list, the rule will not be included in the SG"
  default     = []
}

variable "allow_weka_api_cidrs" {
  type        = list(string)
  description = "allow connection to port 14000 on weka backends and LB(if exists and not provided with dedicated SG)  from specified CIDRs, by default no CIDRs are allowed. All ports (including 14000) are allowed within VPC"
  default     = []
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

variable "subnet_autocreate_as_private" {
  type        = bool
  default     = false
  description = "Create private subnet using nat gateway to route traffic. The default is public network. Relevant only when subnet_ids is empty."
}

variable "endpoint_vpcsc_internal_ip_address" {
  type        = string
  default     = "10.0.1.6"
  description = "Private ip for vpc service connection endpoint"
}

variable "endpoint_apis_internal_ip_address" {
  type        = string
  default     = "10.0.1.5"
  description = "Private ip for all-apis endpoint"
}

variable "cloud_run_dns_zone_name" {
  type        = string
  default     = ""
  description = "Name of existing Private dns zone for domain run.app."
}

variable "googleapis_dns_zone_name" {
  type        = string
  default     = ""
  description = "Name of existing Private dns zone for domain googleapis.com."
}

variable "network_project_id" {
  type        = string
  default     = ""
  description = "Network project id"
}

variable "vpc_connector_region_map" {
  type        = map(string)
  description = "Map of region to use for vpc connector, as some regions do not have cloud functions enabled, and vpc connector needs to be in the same region"
  default = {
    europe-west4       = "europe-west1"
    europe-north1      = "europe-west1",
    us-east5           = "us-east1",
    southamerica-west1 = "northamerica-northeast1",
    asia-south2        = "asia-south1",
  }
}
