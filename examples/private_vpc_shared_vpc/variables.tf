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

variable "host_project" {
  type    = string
  default = "The ID of the project that will serve as a Shared VPC host project"
}

variable "shared_vpcs" {
  type        = list(string)
  description = "List of shared vpc name"
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
  description = "list of connector to use for serverless vpc access"
}

variable "cluster_name" {
  type        = string
  description = "cluster prefix for all resources"
}

variable "private_network" {
  type        = bool
  description = "deploy weka in private network"
}

variable "host_shared_range" {
  type = list(string)
  description = "list of host range to allow sg"
}

variable "prefix" {
  type        = string
  description = "Prefix for all resources"
  default     = "weka"
}