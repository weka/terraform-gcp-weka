variable "cluster_name" {
  type        = string
  description = "Cluster prefix for all resources"
  validation {
    condition     = length(var.cluster_name) <= 37
    error_message = "The cluster name maximum allowed length is 37."
  }
}

variable "project_id" {
  type        = string
  description = "Project id"
}

variable "nics_numbers" {
  type        = number
  description = "Number of nics per host"
  default     = -1

  validation {
    condition     = var.nics_numbers == -1 || var.nics_numbers > 0
    error_message = "The nics_number value can take values > 0 or -1 (for using defaults)."
  }
}

variable "vpcs_number" {
  type        = number
  description = "number of vpcs"
  default     = 4
}

variable "mtu_size" {
  type        = number
  description = "mtu size"
  default     = 1460
}

variable "vpcs_name" {
  type        = list(string)
  description = "List of vpcs name"
  default     = []
}

variable "prefix" {
  type        = string
  description = "Prefix for all resources"
  default     = "weka"

  validation {
    condition     = length(var.prefix) <= 15
    error_message = "The prefix maximum allowed length is 15."
  }
}

variable "zone" {
  type        = string
  description = "Zone name"
}

variable "machine_type" {
  type        = string
  description = "Weka cluster backends machines type"
  default     = "c2-standard-8"
  validation {
    condition     = contains(["c2-standard-8", "c2-standard-16"], var.machine_type)
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

variable "assign_public_ip" {
  type        = bool
  default     = true
  description = "Determines whether to assign public ip."
}

variable "get_weka_io_token" {
  type        = string
  description = "Get get.weka.io token for downloading weka"
  sensitive   = true
  default     = ""
}

variable "install_weka_url" {
  type        = string
  description = "Path to weka installation tar object"
  default     = ""
}

variable "weka_version" {
  type        = string
  description = "Weka version"
  default     = "4.2.1"
}

variable "weka_username" {
  type        = string
  description = "Weka cluster username"
  default     = "admin"
}

variable "cluster_size" {
  type        = number
  description = "Weka cluster size"

  validation {
    condition     = var.cluster_size >= 6
    error_message = "Cluster size should be at least 6."
  }
}

variable "subnets_range" {
  type        = list(string)
  description = "List of subnets to use for creating the cluster, the number of subnets must be 'nics_number'"
  default     = ["10.0.0.0/24", "10.1.0.0/24", "10.2.0.0/24", "10.3.0.0/24"]
}

variable "subnets_name" {
  type        = list(string)
  description = "Subnets list name "
  default     = []
}

variable "vpc_connector_range" {
  type        = string
  description = "list of connector to use for serverless vpc access"
  default     = "10.8.0.0/28"
}

variable "vpc_connector_name" {
  type        = string
  description = "exiting vpc connector name to use for cloud functions"
  default     = ""
}

variable "sa_email" {
  type        = string
  description = "Service account email"
  default     = ""
}

variable "create_cloudscheduler_sa" {
  type        = bool
  description = "Should or not crate gcp cloudscheduler sa"
  default     = true
}

variable "yum_repo_server" {
  type        = string
  description = "Yum repo server address"
  default     = ""
}

variable "allow_ssh_ranges" {
  type        = list(string)
  description = "Allow port 22, if not provided, i.e leaving the default empty list, the rule will not be included in the SG"
  default     = []
}

variable "allow_weka_api_ranges" {
  type        = list(string)
  description = "Allow port 14000, if not provided, i.e leaving the default empty list, the rule will not be included in the SG"
  default     = []
}

variable "source_image_id" {
  type        = string
  description = "Source image id"
  default     = "projects/centos-cloud/global/images/centos-7-v20220719"
}

variable "private_zone_name" {
  type        = string
  description = "Private zone name"
  default     = ""
}

variable "private_dns_name" {
  type        = string
  description = "Private dns name"
  default     = ""
}


variable "cloud_scheduler_region_map" {
  type        = map(string)
  description = "Map of region to use for workflows scheduler, as some regions do not have scheduler enabled"
  default = {
    europe-west4       = "europe-west1"
    europe-north1      = "europe-west1",
    us-east5           = "us-east1",
    southamerica-west1 = "northamerica-northeast1",
    asia-south2        = "asia-south1",
  }
}

variable "cloud_functions_region_map" {
  type        = map(string)
  description = "Map of region to use for cloud functions, as some regions do not have cloud functions enabled"
  default = {
    europe-west4       = "europe-west1"
    europe-north1      = "europe-west1",
    us-east5           = "us-east1",
    southamerica-west1 = "northamerica-northeast1",
    asia-south2        = "asia-south1",
  }
}

variable "workflow_map_region" {
  type        = map(string)
  description = "Map of region to use for workflow, as some regions do not have cloud workflow enabled"
  default = {
    southamerica-west1 = "southamerica-east1"
  }
}

variable "worker_pool_name" {
  type        = string
  description = "Name of worker pool, Must be on the same project and region"
  default     = ""
}

variable "worker_machine_type" {
  type        = string
  description = "Machine type of a worker"
  default     = "e2-standard-4"
}

variable "worker_disk_size" {
  type        = number
  description = "Size of the disk attached to the worker, in GB"
  default     = 100
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
    memory   = list(string)
  }))
  description = "Maps the number of objects and memory size per machine type."
  default = {
    c2-standard-8 = {
      compute  = 1
      drive    = 1
      frontend = 1
      nics     = 4
      memory   = ["4.2GB", "4GB"]
    },
    c2-standard-16 = {
      compute  = 4
      drive    = 1
      frontend = 1
      nics     = 7
      memory   = ["24.2GB", "23.2GB"]
    }
  }
}

variable "protection_level" {
  type        = number
  default     = 2
  description = "Cluster data protection level."
  validation {
    condition     = var.protection_level == 2 || var.protection_level == 4
    error_message = "Allowed protection_level values: [2, 4]."
  }
}

variable "stripe_width" {
  type        = number
  default     = -1
  description = "Stripe width = cluster_size - protection_level - 1 (by default)."
  validation {
    condition     = var.stripe_width == -1 || var.stripe_width >= 3 && var.stripe_width <= 16
    error_message = "The stripe_width value can take values from 3 to 16."
  }
}

variable "hotspare" {
  type        = number
  default     = 1
  description = "Hot-spare value."
}

variable "default_disk_size" {
  type        = number
  default     = 48
  description = "The default disk size."
}

variable "traces_per_ionode" {
  default     = 10
  type        = number
  description = "The number of traces per ionode. Traces are low-level events generated by Weka processes and are used as troubleshooting information for support purposes."
}

variable "obs_name" {
  type        = string
  default     = ""
  description = "Name of OBS cloud storage"
}

variable "set_obs_integration" {
  type        = bool
  default     = false
  description = "Determines whether to enable object stores integration with the Weka cluster. Set true to enable the integration."
}

variable "tiering_ssd_percent" {
  type        = number
  default     = 20
  description = "When OBS integration set to true , this parameter sets how much of the filesystem capacity should reside on SSD. For example, if this parameter is 20 and the total available SSD capacity is 20GB, the total capacity would be 100GB"
}

variable "add_frontend_container" {
  type        = bool
  default     = true
  description = "Create cluster with FE containers"
}

variable "state_bucket_name" {
  type        = string
  default     = ""
  description = "Name of bucket state, cloud storage"
}

variable "proxy_url" {
  type        = string
  description = "Weka home proxy url"
  default     = ""
}

variable "worker_pool_network" {
  type        = string
  default     = ""
  description = "Network name of worker pool, Must be on the same project and region"
}

variable "create_worker_pool" {
  type        = bool
  default     = false
  description = "Create worker pool"
}

variable "set_worker_pool_network_peering" {
  type        = bool
  description = "Create peering between worker pool network and vpcs networks"
  default     = false
}

######################## shared vpcs variables ##########################
variable "host_project" {
  type        = string
  description = "The ID of the project that will serve as a Shared VPC host project"
  default     = ""
}

variable "shared_vpcs" {
  type        = list(string)
  description = "list of shared vpc name"
  default     = []
}

variable "host_shared_range" {
  type        = list(string)
  description = "List of host range to allow sg"
  default     = []
}

############################### clients ############################
variable "clients_number" {
  type        = number
  description = "The number of client virtual machines to deploy."
  default     = 0
}

variable "client_instance_type" {
  type        = string
  description = "The client virtual machine type (sku) to deploy."
  default     = "c2-standard-8"
}

variable "client_nics_num" {
  type        = string
  description = "The client NICs number."
  default     = 2
}

variable "mount_clients_dpdk" {
  type        = bool
  default     = true
  description = "Mount weka clients in DPDK mode"
}

############################################### nfs protocol gateways variables ###################################################
variable "nfs_protocol_gateways_number" {
  type        = number
  description = "The number of protocol gateway virtual machines to deploy."
  default     = 0
}

variable "nfs_protocol_gateway_secondary_ips_per_nic" {
  type        = number
  description = "Number of secondary IPs per single NIC per protocol gateway virtual machine."
  default     = 3
}

variable "nfs_protocol_gateway_machine_type" {
  type        = string
  description = "The protocol gateways' virtual machine type (sku) to deploy."
  default     = "c2-standard-8"
}

variable "nfs_protocol_gateway_nics_num" {
  type        = string
  description = "The protocol gateways' NICs number."
  default     = 2
}

variable "nfs_protocol_gateway_disk_size" {
  type        = number
  default     = 375
  description = "The protocol gateways' default disk size."
}

variable "nfs_protocol_gateway_frontend_cores_num" {
  type        = number
  default     = 1
  description = "The number of frontend cores on single protocol gateway machine."
}

variable "nfs_setup_protocol" {
  type        = bool
  description = "Config protocol, default if false"
  default     = false
}

############################################### smb protocol gateways variables ###################################################
variable "smb_protocol_gateways_number" {
  type        = number
  description = "The number of protocol gateway virtual machines to deploy."
  default     = 0
}

variable "smb_protocol_gateway_secondary_ips_per_nic" {
  type        = number
  description = "Number of secondary IPs per single NIC per protocol gateway virtual machine."
  default     = 3
}

variable "smb_protocol_gateway_machine_type" {
  type        = string
  description = "The protocol gateways' virtual machine type (sku) to deploy."
  default     = "c2-standard-8"
}

variable "smb_protocol_gateway_nics_num" {
  type        = string
  description = "The protocol gateways' NICs number."
  default     = 2
}

variable "smb_protocol_gateway_disk_size" {
  type        = number
  default     = 375
  description = "The protocol gateways' default disk size."
}

variable "smb_protocol_gateway_frontend_cores_num" {
  type        = number
  default     = 1
  description = "The number of frontend cores on single protocol gateway machine."
}

variable "smb_setup_protocol" {
  type        = bool
  description = "Config protocol, default if false"
  default     = false
}

variable "smbw_enabled" {
  type        = bool
  default     = false
  description = "Enable SMBW protocol. This option should be provided before cluster is created to leave extra capacity for SMBW setup."
}

variable "smb_cluster_name" {
  type        = string
  description = "The name of the SMB setup."
  default     = "Weka-SMB"

  validation {
    condition     = length(var.smb_cluster_name) > 0
    error_message = "The SMB cluster name cannot be empty."
  }
}

variable "smb_domain_name" {
  type        = string
  description = "The domain to join the SMB cluster to."
  default     = ""
}

variable "smb_domain_netbios_name" {
  type        = string
  description = "The domain NetBIOS name of the SMB cluster."
  default     = ""
}

variable "smb_dns_ip_address" {
  type        = string
  description = "DNS IP address"
  default     = ""
}

variable "smb_share_name" {
  type        = string
  description = "The name of the SMB share"
  default     = "default"
}

variable "weka_home_url" {
  type        = string
  description = "Weka Home url"
  default     = ""
}

variable "ssh_user" {
  type        = string
  description = "The user name for logging in to the virtual machines."
  default     = "weka"
}

variable "ssh_public_key" {
  type        = string
  description = "Ssh public key to pass to vms."
  default     = null
}
