variable "project" {
  type        = string
  description = "project id"
}

variable "region" {
  type        = string
  description = "region name"
}

variable "vpcs" {
  type       = list(string)
  description = "List of vpcs name"
  default = []
}

variable "prefix" {
  type        = string
  description = "prefix for all resources"
}

variable "worker_machine_type" {
  type = string
  description = "Machine type of a worker"
  default = "e2-standard-4"
}

variable "worker_disk_size" {
  type = number
  description = "ize of the disk attached to the worker, in GB"
  default = 100
}

variable "cluster_name" {
  type        = string
  description = "cluster prefix for all resources"
}

variable "set_worker_pool_network_peering" {
  type = bool
  description = "Create peering between worker pool network and vpcs networks"
  default = false
}

variable "worker_pool_network" {
  type = string
  default = ""
  description = "Network name of worker pool, Must be on the same project and region"
}

variable "sa_email" {
  type = string
  description = "service account email"
}

variable "worker_pool_name" {
  type = string
  default = ""
}