variable "bucket_name" {
  type        = string
  description = "bucket name"
  default     = "weka-infra-backend"
}

variable "project" {
  type        = string
  description = "project name"
  default     = "wekaio-rnd"
}

variable "location" {
  type        = string
  description = "location"
  default     = "EU"
}

variable "prefix" {
  type = string
  default = "weka"
}