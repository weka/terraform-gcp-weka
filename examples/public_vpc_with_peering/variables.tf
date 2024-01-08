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

variable "vpc_to_peer_project_id" {
  description = "Shared vpc project id"
  type        = string
}
