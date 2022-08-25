variable "cluster_name" {
  type        = string
  description = "cluster prefix for all resources"
}

variable "project" {
  type        = string
  description = "project id"
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

variable "zone" {
  type        = string
  description = "zone name"
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

variable "private_network" {
  type        = bool
  description = "deploy weka in private network"
}

variable "get_weka_io_token" {
  type        = string
  description = "get.weka.io token for downloading weka"
  default     = ""
}

variable "install_url" {
  type        = string
  description = "path to weka installation tar object"
  default     = ""
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

variable "cluster_size" {
  type        = number
  description = "weka cluster size"
}

variable "internal_bucket_location" {
  type        = string
  description = "functions and state bucket location"
}

variable "subnets_name" {
  type = list(string)
}

variable "vpc_connector" {
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
  default = true
}

variable "yum_repo_server" {
  type = string
  description = "yum repo server address"
  default     = ""
}

variable "weka_image_id" {
  type = string
  description = "weka image id"
  default = "projects/centos-cloud/global/images/centos-7-v20220719"
}

variable "private_dns_zone" {
  type = string
  description = "Name of private dns zone"
}

variable "private_dns_name" {
  type = string
  description = "Private dns name"
}


variable "cloud_scheduler_region_map" {
  type = map(string)
  description = "Map of region to use for workflows scheduler, as some regions do not have scheduler enabled"
  default = {
    europe-west4 = "europe-west1"
  }
}

variable "cloud_functions_region_map" {
  type = map(string)
  description = "Map of region to use for cloud functions, as some regions do not have cloud functions enabled"
  default = {
    europe-west4 = "europe-west1"
  }
}