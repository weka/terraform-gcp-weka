variable "project_id" {
  type        = string
  description = "Project id"
}

variable "region" {
  type        = string
  description = "Region name"
}

variable "vpc_name" {
  type        = string
  description = "Vpc name"
  default     = ""
}

variable "prefix" {
  type        = string
  description = "Prefix for all resources"
  default     = "weka"
}

variable "worker_machine_type" {
  type        = string
  description = "Machine type of a worker"
}

variable "worker_disk_size" {
  type        = number
  description = "Size of the disk attached to the worker, in GB"
}

variable "cluster_name" {
  type        = string
  description = "Cluster prefix for all resources"
}

variable "worker_pool_id" {
  type        = string
  default     = ""
  description = "Exiting worker pool id"
}

variable "network_project_id" {
  type        = string
  default     = ""
  description = "Network project id"
}

variable "worker_address" {
  type        = string
  description = "Choose an address range for the Cloud Build Private Pool workers. example: 10.37.0.0. Do not include a prefix length."
  default     = "10.37.0.0"
}

variable "worker_address_prefix_length" {
  type        = string
  description = "Prefix length, such as 24 for /24 or 16 for /16. Must be 24 or lower."
  default     = "16"
}
