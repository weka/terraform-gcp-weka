variable "cluster_name" {
  type        = string
  description = "Cluster prefix for all resources"
  validation {
    condition     = length(var.cluster_name) <= 37
    error_message = "The cluster name maximum allowed length is 37."
  }
}

variable "project" {
  type        = string
  description = "Project id"
}

variable "nics_number" {
  type        = number
  description = "Number of nics per host"
  default = -1

  validation {
    condition     = var.nics_number == -1 || var.nics_number > 0
    error_message = "The nics_number value can take values > 0 or -1 (for using defaults)."
  }
}

variable "vpcs" {
  type = list(string)
  description = "List of vpcs name"
}

variable "prefix" {
  type        = string
  description = "Prefix for all resources"
  default = "weka"
}

variable "zone" {
  type        = string
  description = "Zone name"
}

variable "machine_type" {
  type        = string
  description = "Weka cluster backends machines type"
  default = "c2-standard-8"
  validation {
    condition = contains(["c2-standard-8", "c2-standard-16"], var.machine_type)
    error_message = "Machine type isn't supported"
  }
}

variable "region" {
  type        = string
  description = "Region name"
}

variable "nvmes_number" {
  type        = number
  description = "Number of local nvmes per host"
}

variable "private_network" {
  type        = bool
  description = "Deploy weka in private network"
  default = false
}

variable "get_weka_io_token" {
  type        = string
  description = "Get get.weka.io token for downloading weka"
  sensitive   = true
  default     = ""
}

variable "install_url" {
  type        = string
  description = "Path to weka installation tar object"
  default     = ""
}

variable "weka_version" {
  type        = string
  description = "Weka version"
  default = "4.2.0"
}

variable "weka_username" {
  type        = string
  description = "Weka cluster username"
  default = "admin"
}

variable "cluster_size" {
  type        = number
  description = "Weka cluster size"

  validation {
    condition = var.cluster_size >= 6
    error_message = "Cluster size should be at least 6."
  }
}

variable "subnets_name" {
  type = list(string)
  description = "Subnets list name "
}

variable "vpc_connector" {
  type        = string
  description = "Connector name to use for serverless vpc access"
}

variable "sa_email" {
  type = string
  description = "Service account email"
}

variable "create_cloudscheduler_sa" {
  type = bool
  description = "Should or not crate gcp cloudscheduler sa"
  default = true
}

variable "yum_repo_server" {
  type = string
  description = "Yum repo server address"
  default     = ""
}

variable "weka_image_id" {
  type = string
  description = "Weka image id"
  default = "projects/centos-cloud/global/images/centos-7-v20220719"
}

variable "private_dns_zone" {
  type = string
  description = "Name of private dns zone"
}

variable "private_dns_name" {
  type = string
  description = "Private dns name"
}


variable "cloud_scheduler_region_map" {
  type = map(string)
  description = "Map of region to use for workflows scheduler, as some regions do not have scheduler enabled"
  default = {
    europe-west4 = "europe-west1"
    europe-north1 = "europe-west1",
    us-east5 = "us-east1",
    southamerica-west1 = "northamerica-northeast1",
    asia-south2 = "asia-south1",
  }
}

variable "cloud_functions_region_map" {
  type = map(string)
  description = "Map of region to use for cloud functions, as some regions do not have cloud functions enabled"
  default = {
    europe-west4 = "europe-west1"
    europe-north1 = "europe-west1",
    us-east5 = "us-east1",
    southamerica-west1 = "northamerica-northeast1",
    asia-south2 = "asia-south1",
  }
}

variable "workflow_map_region" {
  type = map(string)
  description = "Map of region to use for workflow, as some regions do not have cloud workflow enabled"
  default     = {
    southamerica-west1 = "southamerica-east1"
  }
}

variable "worker_pool_name" {
  type = string
  description = "Name of worker pool, Must be on the same project and region"
  default = ""
}

variable "container_number_map" {
  # NOTE: compute = nics-drive-frontend-1
  # To calculate memory, weka resource generator was used:
  # https://github.com/weka/tools/blob/master/install/resources_generator.py
  # e.g., for 'c2-standard-8': python3 gen.py --net eth0 --compute-dedicated-cores 1 --drive-dedicated-cores 1
  type = map(object({
    compute  = number
    drive    = number
    frontend = number
    nics     = number
    memory   = string
  }))
  description = "Maps the number of objects and memory size per machine type."
  default = {
    c2-standard-8 = {
      compute  = 1
      drive    = 1
      frontend = 1
      nics     = 4
      memory   = "8033846653B"
    },
    c2-standard-16 = {
      compute  = 4
      drive    = 1
      frontend = 1
      nics     = 7
      memory   = "23156228928B"
    }
  }
}

variable "protection_level" {
  type = number
  default = 2
  description = "Cluster data protection level."
  validation {
    condition     = var.protection_level == 2 || var.protection_level == 4
    error_message = "Allowed protection_level values: [2, 4]."
  }
}

variable "stripe_width" {
  type = number
  default = -1
  description = "Stripe width = cluster_size - protection_level - 1 (by default)."
  validation {
    condition     = var.stripe_width == -1 || var.stripe_width >= 3 && var.stripe_width <= 16
    error_message = "The stripe_width value can take values from 3 to 16."
  }
}

variable "hotspare" {
  type = number
  default = 1
  description = "Hot-spare value."
}
