variable "project" {
  type        = string
  description = "project id"
  default = "wekaio-ci"
}

variable "prefix" {
  type        = string
  description = "prefix for all resources"
  default = "weka"
}

variable "sa_name" {
  type = string
  description = "service account name"
  default = "botty"
}