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


variable "vpc_connector_range" {
  type = string
  description = "list of connector to use for serverless vpc access"
}

variable "vpc_connector_name" {
  type = string
  description = "name of existing vpc connector"
  default = ""
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

variable "sa_name" {
  type = string
  description = "service account name"
}

variable "cluster_name" {
  type        = string
  description = "cluster name"
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

variable "path_to_modules" {
  type = string
  description = "path to modules, relative to actual project location or absolute"
  default = "../.."
}
