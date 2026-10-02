variable "project_id" {
  type        = string
  description = "Project id"
}

variable "zone" {
  type        = string
  description = "Zone name"
}

variable "region" {
  type        = string
  description = "Region name"
}

variable "machine_type" {
  type        = string
  description = "The virtual machine type (sku) to deploy"
  default     = "n2-standard-4"
}

variable "subnets_list" {
  type        = list(string)
  description = "list of subnet names"
}

variable "network_project_id" {
  type        = string
  default     = ""
  description = "Network project id"
}

variable "data_services_number" {
  type        = number
  description = "The number of virtual machines to deploy as data services."
}

variable "data_services_name" {
  type        = string
  description = "The data services name."
}

variable "source_image_id" {
  type        = string
  description = "Source image id"
}

variable "sa_email" {
  type        = string
  description = "service account email"
}

variable "assign_public_ip" {
  type        = bool
  description = "Determines whether to assign public ip."
}

variable "weka_volume_size" {
  type        = number
  description = "The disk size."
}

variable "root_volume_size" {
  type        = number
  default     = null
  description = "The root volume size in GB."
}

variable "vm_username" {
  type        = string
  description = "The user name for logging in to the virtual machines."
  default     = "weka"
}

variable "ssh_public_key" {
  type        = string
  description = "Ssh public key to pass to vms."
}

variable "yum_repository_baseos_url" {
  type        = string
  description = "URL of the AppStream repository for baseos. Leave blank to use the default repositories."
  default     = ""
}

variable "yum_repository_appstream_url" {
  type        = string
  description = "URL of the AppStream repository for appstream. Leave blank to use the default repositories."
  default     = ""
}

variable "proxy_url" {
  type        = string
  description = "Weka home proxy url"
  default     = ""
}

variable "deploy_function_url" {
  type        = string
  description = "The URL of deploy function from cloud functions."
}

variable "report_function_url" {
  type        = string
  description = "The URL of report function from cloud functions."
}

variable "labels_map" {
  type        = map(string)
  default     = {}
  description = "A map of labels to assign the same metadata to all resources in the environment. Format: key:value."
}

variable "placement_policies" {
  type        = list(string)
  default     = []
  description = "Self links of the placement resource policies to attach to the instances. GCP supports at most one policy per instance."
}

variable "reservation_consume_type" {
  type        = string
  default     = null
  description = "Reservation affinity consume type of the instances: NO_RESERVATION, ANY_RESERVATION or SPECIFIC_RESERVATION. Leave null to omit the reservation affinity, which keeps the GCP default of consuming any matching reservation."
}

variable "reservation_name" {
  type        = string
  default     = null
  description = "Name of the reservation the instances consume when reservation_consume_type is SPECIFIC_RESERVATION. A reservation owned by another project and shared with this one is named projects/<owner-project-id>/reservations/<reservation-name>. It only accepts instances whose machine type, min CPU platform, GPUs and local SSDs match it exactly. Leave null to give the instances no reservation affinity."
}
