variable "project" {
  type        = string
  description = "project name"
}

variable "region" {
  type        = string
  description = "region name"
}

variable "zone" {
  type        = string
  description = "zone name"
}

variable "vpc_name" {
  type        = string
  description = "vpc name"
}

variable "subnet_name" {
  type        = string
  description = "subnet name"
}

variable "machine_type" {
  type        = string
  description = "weka cluster backends machines type"
}

variable "sa_email" {
  type = string
  description = "service account email"
}

variable "weka_image_name" {
  type = string
  description = "weka image name"
}

variable "weka_image_project" {
  type = string
  description = "weka image project"
}
