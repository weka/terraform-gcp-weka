variable "get_weka_io_token" {
  type        = string
  description = "Get get.weka.io token for downloading weka"
  sensitive   = true
}

variable "project_id" {
  type        = string
  description = "Project id"
}

variable "region" {
  type        = string
  description = "Region name"
}

variable "zone" {
  type        = string
  description = "Zone name"
}
