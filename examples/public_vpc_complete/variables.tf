variable "project" {
  type        = string
  description = "project name"
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

variable "host_shared_range" {
  type = list(string)
  description = "list of host range to allow sg"
  default = []
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

variable "bucket_location" {
  type        = string
  description = "bucket function location"
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
  description = "cluster name"
}

variable "get_weka_io_token" {
  type        = string
  description = "get.weka.io token for downloading weka"
}

variable "sg_public_ssh_cidr_range" {
  type        = list(string)
  description = "list of ranges to allow ssh on public deployment"
}

variable "create_cloudscheduler_sa" {
  type        = bool
  description = "should or not crate gcp cloudscheduler sa"
}

variable "private_network" {
  type        = bool
  description = "deploy weka in private network"
}

variable "weka_image_name" {
  type = string
  description = "weka image name"
}

variable "weka_image_project" {
  type        = string
  description = "weka image project"
}

variable "set_peering" {
  type        = bool
  description = "apply peering connection between subnets and subnets "
}

variable "create_vpc_connector" {
  type        = bool
  description = "create vpc connector"
}