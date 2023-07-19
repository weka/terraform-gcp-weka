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

variable "install_url" {
  type        = string
  description = "Path to weka installation tar object"
}

variable "nvmes_number" {
  type        = number
  description = "Number of local nvmes per host"
}

variable "yum_repo_server" {
  type        = string
  description = "Yum repo server address"
}

variable "subnets_cidr_range" {
  type        = list(string)
  description = "List of subnets to use for creating the cluster, the number of subnets must be 'nics_number'"
}

variable "vpc_connector_range" {
  type        = string
  description = "List of connector to use for serverless vpc access"
}

variable "clusters_name" {
  type        = list(string)
  description = "List of cluster name"
}

variable "private_network" {
  type        = bool
  description = "Deploy weka in private network"
}
