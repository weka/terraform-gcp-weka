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
  type = string
  default = "The ID of the project that will serve as a Shared VPC host project"
}

variable "shared_vpcs" {
  type = list(string)
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

variable "weka_username" {
  type        = string
  description = "weka cluster username"
  default = "admin"
}

variable "internal_bucket_location" {
  type        = string
  description = "functions and state bucket location"
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
  type = string
  description = "service account name"
}

variable "clusters_name" {
  type        = list(string)
  description = "List of cluster name"
}

variable "get_weka_io_token" {
  type        = string
  description = "get.weka.io token for downloading weka"
  sensitive   = true
}

variable "sg_public_ssh_cidr_range" {
  type        = list(string)
  description = "list of ranges to allow ssh on public deployment"
}

variable "private_network" {
  type        = bool
  description = "deploy weka in private network"
}
