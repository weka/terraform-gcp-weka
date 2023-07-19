variable "project_id" {
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

variable "cluster_size" {
  type        = number
  description = "Weka cluster size"
}

variable "nvmes_number" {
  type        = number
  description = "Number of local nvmes per host"
}
variable "vpcs" {
  type        = list(string)
  description = "List of vpcs name"
}

variable "subnets" {
  description = "Details of existing subnets, the key is contain subnet name"
  type = list(string)
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

variable "worker_pool_name" {
  type = string
  description = "Name of worker pool"
}

variable "worker_pool_network" {
  type = string
  description = "Network name of worker pool"
}
