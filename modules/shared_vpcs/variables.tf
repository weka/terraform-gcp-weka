variable "project" {
  type        = string
  description = "project name"
}

variable "prefix" {
  type        = string
  description = "prefix for all resources"
}

variable "host_project" {
  type = string
  default = "The ID of the project that will serve as a Shared VPC host project"
}

variable "shared_vpcs" {
  type = list(string)
  description = "list of shared vpc name"
}

variable "vpcs" {
  type = list(string)
  description = "list of vpcs name"
}

variable "deploy_on_host_project" {
  type = bool
}

variable "service_project" {
  type        = string
  description = "project id of service project"
  default     = ""
}

variable "sa_email" {
  type = string
  description = "service account email"
  default = ""
}