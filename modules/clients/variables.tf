variable "project_id" {
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

variable "assign_public_ip" {
  type        = bool
  default     = true
  description = "Determines whether to assign public ip."
}

variable "subnets_list" {
  type        = list(string)
  description = "list of subnet names"
}

variable "yum_repo_server" {
  type        = string
  description = "yum repo server address"
  default     = ""
}

variable "machine_type" {
  type        = string
  description = "weka cluster clients machines type"
}

variable "sa_email" {
  type        = string
  description = "service account email"
}

variable "clients_number" {
  type    = string
  default = "Number of clients"
}

variable "source_image_id" {
  type        = string
  description = "os of image"
}

variable "frontend_container_cores_num" {
  type        = number
  description = "Number of frontend cores to use on client instances, this number will reflect on number of NICs attached to instance, as each weka core requires dedicated NIC"
  default     = 1
}

variable "disk_size" {
  type        = number
  description = "size of disk"
}

variable "clients_use_dpdk" {
  type        = bool
  default     = true
  description = "Mount weka clients in DPDK mode"
}

variable "backend_lb_ip" {
  type        = string
  description = "The backend load balancer ip address."
}

variable "clients_name" {
  type        = string
  description = "Prefix clients name."
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

variable "instance_config_overrides" {
  type = map(object({
    dpdk_base_memory_mb = optional(number, 0)
    host_maintenance    = optional(string, "MIGRATE")
  }))
  description = "Maps the number of objects and memory size per machine type."
  default = {
    n2-standard-32 = {
      dpdk_base_memory_mb = 32
    },
    c2d-standard-32 = {
      dpdk_base_memory_mb = 32
    },
    c2d-standard-112 = {
      dpdk_base_memory_mb = 32
    },
    n2-standard-48 = {
      dpdk_base_memory_mb = 32
    },
    c2d-standard-56 = {
      dpdk_base_memory_mb = 32
    },
    n2-standard-128 = {
      dpdk_base_memory_mb = 32
    },
    n2-standard-96 = {
      dpdk_base_memory_mb = 32
    },
    n2d-standard-32 = {
      dpdk_base_memory_mb = 32
    },
    n2d-standard-64 = {
      dpdk_base_memory_mb = 32
    },
    n2d-highmem-32 = {
      dpdk_base_memory_mb = 32
    },
    n2d-highmem-64 = {
      dpdk_base_memory_mb = 32
    },
    n2-highmem-32 = {
      dpdk_base_memory_mb = 32
    },
    c2d-highmem-56 = {
      dpdk_base_memory_mb = 32
    },
    a2-highgpu-1g = {
      host_maintenance = "TERMINATE"
    },
    a2-highgpu-2g = {
      host_maintenance    = "TERMINATE"
      dpdk_base_memory_mb = 32
    },
    a2-highgpu-4g = {
      host_maintenance    = "TERMINATE"
      dpdk_base_memory_mb = 32
    },
    a2-highgpu-8g = {
      host_maintenance    = "TERMINATE"
      dpdk_base_memory_mb = 32
    },
    a2-megagpu-16g = {
      host_maintenance    = "TERMINATE"
      dpdk_base_memory_mb = 32
    }
  }
}
