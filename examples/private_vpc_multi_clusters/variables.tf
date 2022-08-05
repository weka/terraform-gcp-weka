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

variable "internal_bucket_location" {
  type        = string
  description = "functions and state bucket location"
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

variable "clusters_name" {
  type        = list(string)
  description = "List of cluster name"
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
