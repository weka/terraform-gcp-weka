variable "project" {
  type        = string
  description = "project name"
  default     = "wekaio-rnd"
}

variable "region" {
  type        = string
  description = "region name"
  default     = "europe-west1"
}

variable "pub_ip_cidr_range" {
  type = string
  default = "10.26.2.0/24"
}

variable "pri_ip_cidr_range" {
  type = string
  default = "10.26.1.0/24"
}

variable "zone" {
  type = string
  default = "europe-west1-b"
}

variable "private_key_filename" {
  type        = string
  description = "local private_key filename"
  default     = ".ssh/repo-ssh-key"
}

variable "ssh_user" {
  type    = string
  default = "weka"
}

variable "machine_type" {
  type = string
  default = "c2-standard-4"
}

variable "storage_bucket" {
  type = string
  default = "weka-infra-backend"
}

variable "vpcs-peering" {
  type = list(string)
  default = ["weka-vpc-0","weka-vpc-1","weka-vpc-2","weka-vpc-3"]
}

variable "vpc_range" {
  type = string
  default = "10.0.0.0/24"
}

