variable "project" {
  type        = string
  description = "project name"
  default     = "wekaio-rnd"
}

variable "region" {
  type        = string
  description = "region name"
  default     = "europe-north1"
}

variable "username" {
  type        = string
  description = "username for login "
  default     = "weka"
}

variable "get_weka_io_token" {
  type        = string
  description = "get.weka.io token for downloading weka"
  default     = "must be set outside"
}

variable "weka_version" {
  type        = string
  description = "weka version"
  default     = "3.14.0.44-gcp-beta"
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

variable "subnets" {
  type        = list(string)
  description = "list of subnets to use for creating the cluster, the number of subnets must be 'nics_number'"
  default     = ["10.0.0.0/24", "10.1.0.0/24", "10.2.0.0/24", "10.3.0.0/24"]
}

variable "nvmes_number" {
  type        = number
  description = "number of local nvmes per host"
  default     = 2
}

variable "cluster_name" {
  type        = string
  description = "prefix for all resources"
  default     = "poc"
}

variable "prefix" {
  type        = string
  description = "prefix for all resources"
  default     = "weka"
}

variable "private_key_filename" {
  type        = string
  description = "local private_key filename"
  default     = ".ssh/google_compute_engine"
}

variable "machine_type" {
  type        = string
  description = "weka cluster backends machines type"
  default     = "c2-standard-16"
}
