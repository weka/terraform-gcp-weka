variable "project_id" {
  type        = string
  description = "Project id"
}

variable "region" {
  type        = string
  description = "Region name"
  default     = "europe-west1"
}

variable "zone" {
  type        = string
  description = "Zone name"
  default     = "europe-west1-b"
}
