variable "project" {
  type        = string
  description = "project id"
}

variable "prefix" {
  type        = string
  description = "prefix for all resources"
  default = "weka"
}

variable "service_account_name" {
  type = string
  description = "service account name"
  default = "deployment"
}