variable "cluster_name" {
  type        = string
  description = "cluster prefix for all resources"
}

variable "project" {
  type        = string
  description = "project name"
}

variable "project_number" {
  type        = string
  description = "project number"
}

variable "nics_number" {
  type        = number
  description = "number of nics per host"
}

variable "vpcs" {
  type = list(string)
  description = "List of vpcs name"
}

variable "prefix" {
  type        = string
  description = "prefix for all resources"
}

variable "subnets" {
  type              = map(object({
    gateway-address = string
    vpc-name        = string
    cidr_range       = string
  }))
}

variable "zone" {
  type        = string
  description = "zone name"
}

variable "private_key_filename" {
  type        = string
  description = "local private_key filename"
}

variable "machine_type" {
  type        = string
  description = "weka cluster backends machines type"
}

variable "region" {
  type        = string
  description = "region name"
}

variable "nvmes_number" {
  type        = number
  description = "number of local nvmes per host"
}

variable "username" {
  type        = string
  description = "username for login "
}

variable "get_weka_io_token" {
  type        = string
  description = "get.weka.io token for downloading weka"
}

variable "weka_version" {
  type        = string
  description = "weka version"
}

variable "weka_username" {
  type        = string
  description = "weka cluster username"
}

variable "cluster_size" {
  type        = number
  description = "weka cluster size"
}

variable "gateway_address_list" {
  type = list(string)
  description = "gateway ips list"
}

variable "bucket-location" {
  type = string
  description = "bucket function location"
}

variable "subnets_name" {
  type = list(string)
}

variable "subnets_range" {
  type = list(string)
}

variable "vpc-connector" {
  type        = string
  description = "connector name to use for serverless vpc access"
}

variable "sa_email" {
  type = string
  description = "service account email"
}

variable "create_cloudscheduler_sa" {
  type = bool
  description = "should or not crate gcp cloudscheduler sa"
}