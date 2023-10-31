variable "vpcs_peering_list" {
  type        = list(string)
  description = "list of vpcs name to peering"
}

variable "vpcs_name" {
  type        = list(string)
  description = "list of backend vpcs name"
}
