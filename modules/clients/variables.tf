variable "project_id" {
  type        = string
  description = "project name"
}

variable "region" {
  type        = string
  description = "region name"
}

variable "prefix" {
  type        = string
  description = "prefix for all resources"
}

variable "cluster_name" {
  type        = string
  description = "cluster prefix for all resources"
}

variable "zone" {
  type        = string
  description = "zone name"
}

variable "assign_public_ip" {
  type        = bool
  default     = true
  description = "Determines whether to assign public ip."
}

variable "subnets_list" {
  type        = list(string)
  description = "list of subnet names"
}

variable "yum_repo_server" {
  type        = string
  description = "yum repo server address"
  default     = ""
}

variable "machine_type" {
  type        = string
  description = "weka cluster backends machines type"
}

variable "sa_email" {
  type        = string
  description = "service account email"
}

variable "clients_number" {
  type    = string
  default = "Number of clients"
}

variable "source_image" {
  type = string
  description = "os of image"
}

variable "nics_numbers" {
  type        = number
  description = "Number of core per client"
  default     = 1
}

variable "disk_size" {
  type        = number
  description = "size of disk"
}

variable "mount_clients_dpdk" {
  type        = bool
  default     = true
  description = "Mount weka clients in DPDK mode"
}

variable "backend_lb_ip" {
  type        = string
  description = "The backend load balancer ip address."
}

variable "clients_name" {
  type        = string
  description = "Prefix clients name."
}