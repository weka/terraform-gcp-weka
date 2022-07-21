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

variable "username" {
  type        = string
  description = "username for login "
}

variable "private_network" {
  type        = bool
  description = "deploy weka in private network"
}

variable "get_weka_io_token" {
  type        = string
  description = "get.weka.io token for downloading weka"
}

variable "install_url" {
  type        = string
  description = "path to weka installation tar object"
}

variable "weka_version" {
  type        = string
  description = "weka version"
}

variable "cluster_size" {
  type        = number
  description = "weka cluster size"
  default     = 5
}

variable "nics_number" {
  type        = number
  description = "number of nics per host"
  default     = 4
}

variable "vpcs" {
  type        = list(string)
  description = "List of vpcs name"
  default    = []
}

variable "subnets-cidr-range" {
  type        = list(string)
  description = "list of subnets to use for creating the cluster, the number of subnets must be 'nics_number'"
  default    = []
}

variable "subnets" {
  description = "Details of existing subnets, the key is contain subnet name"
  type = list(string)
  default = []
}

variable "nvmes_number" {
  type        = number
  description = "number of local nvmes per host"
  default     = 2
}

variable "cluster_name" {
  type        = string
  description = "prefix for all resources"
}

variable "prefix" {
  type        = string
  description = "prefix for all resources"
}

variable "machine_type" {
  type        = string
  description = "weka cluster backends machines type"
  default     = "c2-standard-8"
}


variable "weka_username" {
  type        = string
  description = "weka cluster username"
}

variable "set_peering" {
  type = bool
  description = "apply peering connection between subnets and subnets "
  default = true
}

variable "bucket-location" {
  type = string
  description = "bucket function location"
  default = "EU"
}

variable "vpc_connector_range" {
  type = string
  description = "list of connector to use for serverless vpc access"
}

variable "create_vpc_connector" {
  type = bool
  description = " "
  default = true
}

variable "vpc_connector_name" {
  type = string
  description = ""
  default = ""
}

variable "sa_name" {
  type = string
  description = "service account name"
}

variable "sa_email" {
  type = string
  description = "service account email"
  default = ""
}

variable "service_project" {
  type = string
  description = "project id of service project"
  default = ""
}

variable "host_project" {
  type = string
  default = "The ID of the project that will serve as a Shared VPC host project"
}

variable "shared_vpcs" {
  type = list(string)
  description = "list of shared vpc name"
  default = []
}

variable "deploy_on_host_project" {
  type = bool
  default = false
}

variable "create_cloudscheduler_sa" {
  type = bool
  description = "should or not crate gcp cloudscheduler sa"
}

variable "create_shared_vpc" {
  type = bool
  description = "should or not create vpc sharing"
}

variable "yum_repo_server" {
  type = string
  description = "yum repo server address"
}

variable "repo_public_cidr_range" {
  type        = string
  description = "Public range for local repo"
  default     = ""
}

variable "repo_private_cidr_range" {
  type = string
  description = "Private range for local repo"
  default = ""
}

variable "create_local_repo" {
  type = bool
  description = "create a local centos repo for private network"
}

variable "family_image" {
  type = string
  default = "centos-7"
  description = "The family name of the image"
}

variable "project_image" {
  type = string
  default = "centos-cloud"
  description = "The project in which the resource belongs"
}

variable "sg_public_ssh_cidr_range" {
  type        = list(string)
  description = "list of ranges to allow ssh on public deployment"
}

variable "weka_image_name" {
  type = string
  description = "weka image name"
}

variable "weka_image_project" {
  type = string
  description = "weka image project"
}

variable "create_weka_image" {
  type = bool
  description = "should create weka image project"
}
