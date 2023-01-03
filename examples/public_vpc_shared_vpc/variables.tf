variable "project" {
  type        = string
  description = "Project id"
}

variable "region" {
  type        = string
  description = "Region name"
}

variable "zone" {
  type        = string
  description = "Zone name"
}

variable "host_project" {
  type = string
  default = "The ID of the project that will serve as a Shared VPC host project"
}

variable "shared_vpcs" {
  type = list(string)
  description = "List of shared vpc name"
}

variable "cluster_size" {
  type        = number
  description = "Weka cluster size"
}

variable "nvmes_number" {
  type        = number
  description = "Number of local nvmes per host"
}

variable "subnets_cidr_range" {
  type        = list(string)
  description = "List of subnets to use for creating the cluster, the number of subnets must be 'vpcs_number'"
}

variable "vpc_connector_range" {
  type        = string
  description = "List of connector to use for serverless vpc access"
}

variable "cluster_name" {
  type        = string
  description = "Cluster name"
}

variable "get_weka_io_token" {
  type        = string
  description = "Get get.weka.io token for downloading weka"
  sensitive   = true
}

variable "host_shared_range" {
  type = list(string)
  description = "List of host range to allow sg"
  default = []
}
