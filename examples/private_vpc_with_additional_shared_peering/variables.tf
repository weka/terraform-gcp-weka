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

variable "prefix" {
  type        = string
  description = "prefix for all resources"
}

variable "host_project" {
  type    = string
  default = "The ID of the project that will serve as a Shared VPC host project"
}

variable "shared_vpcs" {
  type        = list(string)
  description = "list of shared vpc name"
}

variable "nics_number" {
  type        = number
  description = "number of nics per host"
}

variable "cluster_size" {
  type        = number
  description = "weka cluster size"
}

variable "install_url" {
  type        = string
  description = "path to weka installation tar object"
}

variable "machine_type" {
  type        = string
  description = "weka cluster backends machines type"
}

variable "nvmes_number" {
  type        = number
  description = "number of local nvmes per host"
}

variable "weka_version" {
  type        = string
  description = "weka version"
}

variable "yum_repo_server" {
  type        = string
  description = "yum repo server address"
}

variable "subnets_cidr_range" {
  type        = list(string)
  description = "list of subnets to use for creating the cluster, the number of subnets must be 'nics_number'"
}

variable "vpc_connector_range" {
  type        = string
  description = "list of connector to use for serverless vpc access"
}

variable "sa_name" {
  type        = string
  description = "service account name"
}

variable "cluster_name" {
  type        = string
  description = "cluster prefix for all resources"
}

variable "private_network" {
  type        = bool
  description = "deploy weka in private network"
}

variable "weka_username" {
  type        = string
  description = "weka cluster username"
  default = "admin"
}

variable "host_shared_range" {
  type = list(string)
  description = "list of host range to allow sg"
}

variable "attach_service_project" {
  type        = bool
  description = "Add service project to host project"
  default     = false
}