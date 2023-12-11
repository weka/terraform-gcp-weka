variable "project_id" {
  type        = string
  description = "project id"
}

variable "prefix" {
  type        = string
  description = "prefix for all resources"
  default     = "weka"
}

variable "service_account_name" {
  type        = string
  description = "service account name"
  default     = "deployment"
}

variable "state_bucket_name" {
  type        = string
  default     = ""
  description = "Name of existing state bucket"
}

variable "tiering_obs_name" {
  type        = string
  default     = ""
  description = "Name of existing OBS bucket"
}

variable "cluster_name" {
  type        = string
  description = "Cluster prefix for all resources"
  validation {
    condition     = length(var.cluster_name) <= 37
    error_message = "The cluster name maximum allowed length is 37."
  }
}

variable "weka_tar_bucket_name" {
  type        = string
  default     = ""
  description = "Name of weka tar bucket"
}

variable "weka_tar_project_id" {
  type        = string
  default     = ""
  description = "Project id of weka tar"
}

variable "network_project_id" {
  type        = string
  default     = ""
  description = "Network project id"
}
