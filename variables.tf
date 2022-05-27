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
  type = string
  description = "get.weka.io token for downloading weka"
  default     = "must be set outside"
}

variable "weka_version" {
  type = string
  description = "weka version"
  default     = "3.14.0.44-gcp-beta"
}

variable "cluster_size" {
  type = number
  description = "weka cluster size"
  default     = 5
}
