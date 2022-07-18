variable "project" {
  type        = string
  description = "project name"
}

variable "region" {
  type        = string
  description = "region name"
}

variable "public_cidr_range" {
  type = string
  default = "10.26.2.0/24"
}

variable "private_cidr_range" {
  type = string
  default = "10.26.1.0/24"
}

variable "zone" {
  type = string
  description = "zone of centos repo local server"
}

variable "machine_type" {
  type = string
  default = "c2-standard-4"
  description = "repo image type"
}

variable "vpcs_peering" {
  type = list(string)
  description = "List of vpc to peering repo network"
}

variable "vpc_range" {
  type = string
  default = "10.0.0.0/24"
}

variable "family_image" {
  type = string
  default = "centos-7"
  description = "The family name of the image"
}

variable "project_image" {
  type = string
  default = "centos-cloud"
  description = "The project in which the resource belongs"
}