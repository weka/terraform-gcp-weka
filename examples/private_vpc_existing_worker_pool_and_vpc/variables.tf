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


variable "vpc_connector_range" {
  type        = string
  description = "List of connector to use for serverless vpc access"
}

variable "cluster_name" {
  type        = string
  description = "Cluster name"
}

variable "worker_pool_name" {
  type = string
  description = "Name of worker pool"
}

variable "worker_pool_network" {
  type = string
  description = "Network name of worker pool"
}

variable "install_url" {
  type        = string
  description = "Path to weka installation tar object"
}

variable "yum_repo_server" {
  type = string
  description = "Yum repo server address"
}

variable "private_network" {
  type        = bool
  description = "Deploy weka in private network"
}

variable "vpcs" {
  type        = list(string)
  description = "List of vpcs name"
  default    = []
}

variable "subnets" {
  description = "Details of existing subnets, the key is contain subnet name"
  type = list(string)
  default = []
}

variable "obs_name" {
  type        = string
  default     = ""
  description = "Name of OBS cloud storage"
}

variable "set_obs_integration" {
  type = bool
  description = "Should be true to enable OBS integration with weka cluster"
}

variable "state_bucket_name" {
  type        = string
  default     = ""
  description = "Name of existing state bucket"
}