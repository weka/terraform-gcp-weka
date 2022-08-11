variable "project" {
  type        = string
  description = "project id"
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

variable "sa_email" {
  type = string
  description = "service account email"
  default = ""
}

variable "host_shared_range" {
  type = list(string)
  description = "list of host range to allow sg"
  default = []
}

variable "attach_service_project" {
  type        = bool
  description = "Add service project to host project"
  default     = false
}