variable "project_id" {
  type        = string
  description = "Project id"
}

variable "region" {
  type        = string
  description = "Region name"
  default     = "europe-west1"
}

variable "get_weka_io_token" {
  type        = string
  description = "Get get.weka.io token for downloading weka"
  sensitive   = true
}

variable "host_project" {
  type        = string
  description = "The ID of the project that will serve as a Shared VPC host project"
}
