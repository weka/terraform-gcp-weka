variable "cluster_name" {
  type        = string
  description = "Cluster name prefix for all resources."
  validation {
    condition     = length(var.cluster_name) <= 37
    error_message = "The cluster name must not exceed 37 characters."
  }
}

variable "project_id" {
  type        = string
  description = "Project id"
}

variable "nic_number" {
  type        = number
  description = "Number of NICs per host."
  default     = -1

  validation {
    condition     = var.nic_number == -1 || var.nic_number > 0
    error_message = "The number of NICs can either be greater than 0 or equal to -1."
  }
}

variable "mtu_size" {
  type        = number
  description = "The Maximum Transmission Unit (MTU) size is the largest packet size that can be transmitted over a network."
  default     = 8896
}

variable "vpcs_name" {
  type        = list(string)
  description = "Names of VPC networks to associate with the resource. Depending on your configuration, you can specify 0, 4, or 7 VPC networks."
  default     = []
  validation {
    condition     = length(var.vpcs_name) == 0 || length(var.vpcs_name) == 4 || length(var.vpcs_name) == 7
    error_message = "The provided list of VPC networks is invalid. You can specify 0, 4, or 7 VPC networks."
  }
}

variable "prefix" {
  type        = string
  description = "Prefix for all resources (maximum 15 characters)."
  default     = "weka"

  validation {
    condition     = length(var.prefix) <= 15
    error_message = "The prefix must not exceed 15 characters."
  }
}

variable "zone" {
  type        = string
  description = "GCP zone, which is a deployment area within a region, providing physical separation for your resources."
}

variable "machine_type" {
  type        = string
  description = "The machine type for the WEKA backend instance."
  default     = "c2-standard-8"
}

variable "region" {
  type        = string
  description = "GCP region, a broader geographic area within GCP that houses your resources. It encompasses multiple zones."
}

variable "nvmes_number" {
  type        = number
  description = "Number of NVMe disks to attach to each host."
  default     = 2
}

variable "assign_public_ip" {
  type        = string
  default     = "auto"
  description = "Controls public IP assignment for deployed instances (backends, clients, and gateways)."
  validation {
    condition     = var.assign_public_ip == "true" || var.assign_public_ip == "false" || var.assign_public_ip == "auto"
    error_message = "Invalid public IP assignment. The value for assign_public_ip must be one of the following: [\"true\", \"false\", \"auto\"]."
  }
}

variable "get_weka_io_token" {
  type        = string
  description = "WEKA software download token. Obtain a valid token from https://get.weka.io/ to download and install the WEKA software during deployment."
  sensitive   = true
  default     = ""
}

variable "install_weka_url" {
  type        = string
  description = "The URL to WEKA installation script or tar object. Examples: URL to installation script: https://TOKEN@get.weka.io/dist/v1/install/4.3.1/4.3.1. URL to tar object: https://TOKEN@get.weka.io/dist/v1/pkg/weka-4.3.1.tar. URL to tar object in a cloud bucket: gs://weka-installation/weka-4.2.12.87.tar. (Replace TOKEN with your valid WEKA download token)."
  default     = ""
}

variable "weka_version" {
  type        = string
  description = "WEKA version"
  default     = ""
}

variable "cluster_size" {
  type        = number
  description = "The number of instances deployed for your WEKA cluster."

  validation {
    condition     = var.cluster_size >= 6
    error_message = "WEKA cluster size is too small. Provide a value greater than or equal to 6."
  }
}

variable "subnets_range" {
  type        = list(string)
  description = "List of subnet CIDRs (0, 4, or 7) for cluster creation. 0: No subnets (for single-node testing). 4: Common setup for production (spread across AZs for redundancy). 7: Less common deployments with specific needs."
  default     = ["10.0.0.0/24", "10.1.0.0/24", "10.2.0.0/24", "10.3.0.0/24"]
  validation {
    condition     = length(var.subnets_range) == 0 || length(var.subnets_range) == 4 || length(var.subnets_range) == 7
    error_message = "Invalid number of subnets. Valid options: 0, 4, or 7."
  }
}

variable "subnets_name" {
  type        = list(string)
  description = "List of names (0, 4, or 7) for subnets defined in the subnets_range variable."
  default     = []
  validation {
    condition     = length(var.subnets_name) == 0 || length(var.subnets_name) == 4 || length(var.subnets_name) == 7
    error_message = "Invalid number of subnet names. Set according to subnets_range."
  }
}

variable "vpc_connector_range" {
  type        = string
  description = "VPC connector CIDR block for serverless VPC access."
  default     = "10.8.0.0/28"
}

variable "vpc_connector_id" {
  type        = string
  description = "ID of an existing VPC connector for serverless VPC access in the format: projects/<project-id>/locations/<region>/connectors/<connector-name>. Leave blank to create a new VPC connector during deployment."
  default     = ""
}

variable "vpc_connector_egress_settings" {
  type        = string
  description = "Egress settings for the VPC connector. Possible values: ALL_TRAFFIC, PRIVATE_RANGES_ONLY."
  default     = "PRIVATE_RANGES_ONLY"
  validation {
    condition     = var.vpc_connector_egress_settings == "ALL_TRAFFIC" || var.vpc_connector_egress_settings == "PRIVATE_RANGES_ONLY"
    error_message = "Invalid egress settings for the VPC connector. Possible values: ALL_TRAFFIC, PRIVATE_RANGES_ONLY."
  }
}

variable "sa_email" {
  type        = string
  description = "Email address of an existing service account to be used. Leave blank to create a new service account during deployment."
  default     = ""
}

variable "create_cloudscheduler_sa" {
  type        = bool
  description = "Enables creation of a Cloud Scheduler service account. Set this to false to reuse an existing service account for Cloud Scheduler jobs."
  default     = true
}

variable "yum_repo_server" {
  type        = string
  description = "URL of a Yum repository server for package installation. Leave blank to use the default repositories."
  default     = ""
}

variable "allow_ssh_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks allowed for SSH access (port 22). If empty, SSH access is restricted to all sources (not recommended for production). Example: Allow access from specific IP addresses: allow_ssh_cidrs = [\"10.0.0.1/32\", \"192.168.1.0/24\"]"
  default     = []
}

variable "allow_weka_api_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks allowed for WEKA API access (port 14000). By default, no connections are allowed to port 14000. Specifying CIDRs here restricts access to the WEKA API on its backends and load balancer (if it exists and shares the security group) to the listed sources only. All ports (including 14000) are allowed within the VPC by default."
  default     = []
}

variable "sg_custom_ingress_rules" {
  type = list(object({
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default     = []
  description = "Custom inbound rules to be added to the security group."
}

variable "source_image_id" {
  type        = string
  description = "Source image for deployment (default: rocky-linux-8-v20240910). While other distributions may be compatible, only Rocky Linux 8.10 is officially tested with this Terraform module."
  default     = "rocky-linux-8-v20240910"
}

variable "private_zone_name" {
  type        = string
  description = "Private zone name."
  default     = ""
}

variable "private_dns_name" {
  type        = string
  description = "Private DNS name."
  default     = ""
}

variable "dns_zone_project_id" {
  type        = string
  default     = ""
  description = "Project ID for the DNS zone. If omitted, it uses network project ID or falls back to project ID."
}

variable "cloud_scheduler_region_map" {
  type        = map(string)
  description = "Defines a mapping between regions lacking Cloud Scheduler functionality and alternative regions. It ensures Cloud Scheduler functionality by redirecting workflows to supported regions when necessary."
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
  description = "Defines a mapping between regions lacking Cloud Functions functionality and alternative regions. It ensures Cloud Functions availability by redirecting workflows to supported regions when necessary."
  default = {
    europe-west4       = "europe-west1"
    europe-north1      = "europe-west1",
    us-east5           = "us-east1",
    southamerica-west1 = "northamerica-northeast1",
    asia-south2        = "asia-south1",
  }
}

variable "cloud_run_image_prefix" {
  type        = string
  description = "Image reference for Cloud Functions"
  default     = null
}

variable "workflow_map_region" {
  type        = map(string)
  description = "Defines a mapping between regions lacking Cloud Workflows functionality and alternative regions. It ensures Cloud Workflows functionality by redirecting workflows to supported regions when necessary."
  default = {
    southamerica-west1 = "southamerica-east1"
  }
}

variable "worker_pool_address_cidr" {
  type        = string
  description = "The address range for worker machines within a Cloud Build Private Pool. It follows CIDR notation excluding the prefix length."
  default     = "10.37.0.0"
}

variable "worker_address_prefix_length" {
  type        = string
  description = "The prefix length for IP addresses, expressed in the worker_pool_address_cidr. For example, use 24 for a /24 subnet or 16 for a /16 subnet. The maximum value is 24."
  default     = "16"
}

variable "worker_pool_id" {
  type        = string
  description = "The unique identifier for the worker pool. The worker pool must belong to the same project and region. If left empty, the default worker pool is used."
  default     = ""
}

variable "worker_machine_type" {
  type        = string
  description = "The machine type for a worker."
  default     = "e2-standard-4"
}

variable "worker_disk_size" {
  type        = number
  description = "The size of the disk attached to the worker node in GB."
  default     = 100
}

variable "containers_config_map" {
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
  description = "Defines a mapping of WEKA processes, NICs, and memory specifications for machine types."
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
    },
    n2-standard-8 = {
      compute  = 1
      drive    = 1
      frontend = 1
      nics     = 4
      memory   = ["3.1GB", "1.6GB"]
    },
    n2-standard-16 = {
      compute  = 4
      drive    = 1
      frontend = 1
      nics     = 7
      memory   = ["18.9GB", "18.9GB"]
    }
  }
  validation {
    condition     = alltrue([for m in flatten([for i in values(var.containers_config_map) : (flatten(i.memory))]) : tonumber(trimsuffix(m, "GB")) <= 384])
    error_message = "The compute memory must not exceed 384GB."
  }
}

variable "nic_type" {
  type        = string
  default     = null
  description = "The type of vNIC. Possible values: GVNIC, VIRTIO_NET."

  validation {
    condition     = var.nic_type == null || var.nic_type == "GVNIC" || var.nic_type == "VIRTIO_NET"
    error_message = "The vNIC type must be either GVNIC or VIRTIO_NET."
  }
}

variable "protection_level" {
  type        = number
  default     = 2
  description = "The protection level, referring to the cluster data, indicates the number of additional protection blocks per stripe, either 2 or 4."
  validation {
    condition     = var.protection_level == 2 || var.protection_level == 4
    error_message = "Valid data protection level values are 2 and 4."
  }
}

variable "stripe_width" {
  type        = number
  default     = -1
  description = "The stripe width is the number of blocks sharing a common protection set, which ranges from 3 to 16. By default, stripe_width = cluster_size - protection_level - 1. The default value -1 means the stripe size is calculated automatically; otherwise, the specified value is used."
  validation {
    condition     = var.stripe_width == -1 || var.stripe_width >= 3 && var.stripe_width <= 16
    error_message = "Valid stripe_width values are 3 to 16."
  }
}

variable "hotspare" {
  type        = number
  default     = 1
  description = "A hot spare is the system's ability to withstand the loss of a defined number of failure domains, rebuild data completely, and maintain original net capacity."
}

variable "default_disk_size" {
  type        = number
  default     = 48
  description = "The default disk size."
}

variable "default_disk_name" {
  type        = string
  default     = "wekaio-volume"
  description = "The default disk name."
}

variable "boot_disk_type" {
  type        = string
  default     = "pd-standard"
  description = "The boot disk type."
}

variable "traces_per_ionode" {
  default     = 10
  type        = number
  description = "The number of traces generated per ionode. Traces represent low-level events generated by WEKA processes and are used for support."
}

variable "tiering_obs_name" {
  type        = string
  default     = ""
  description = "The name of the OBS cloud storage used for tiering."
}

variable "tiering_enable_obs_integration" {
  type        = bool
  default     = false
  description = "Controls integration with object stores in the WEKA cluster for tiering. Set to true to enable this integration."
}

variable "tiering_enable_ssd_percent" {
  type        = number
  default     = 20
  description = "When the OBS integration setting is enabled, this parameter sets the percentage of the filesystem capacity that resides on the SSD. For example, if this parameter is set to 20 (percent) and the total available SSD capacity is 20GB, the total capacity is 100 GB."
}

variable "tiering_obs_target_ssd_retention" {
  type        = number
  description = "Target retention period (in seconds) before tiering to OBS (how long data will stay in SSD). Default is 86400 seconds (24 hours)."
  default     = 86400
}

variable "tiering_obs_start_demote" {
  type        = number
  description = "Target tiering cue (in seconds) before starting upload data to OBS (turning it into read cache). Default is 10 seconds."
  default     = 10
}

variable "set_dedicated_fe_container" {
  type        = bool
  default     = false
  description = "Creates a cluster with dedicated frontend containers."
}

variable "state_bucket_name" {
  type        = string
  default     = ""
  description = "The name of a bucket used for state storage in the cloud."
}

variable "proxy_url" {
  type        = string
  description = "The URL for the WEKA Home proxy."
  default     = ""
}

variable "create_worker_pool" {
  type        = bool
  default     = false
  description = "Determines whether to create a worker pool. Set to true if a worker pool is needed."
}

######################## shared vpcs variables ##########################
variable "host_project" {
  type        = string
  description = "The ID of the project that acts as a shared VPC host project."
  default     = ""
}

variable "shared_vpcs" {
  type        = list(string)
  description = "list of shared vpc names."
  default     = []
}

variable "host_shared_range" {
  type        = list(string)
  default     = []
  description = "List of host ranges to allow security groups."
}

############################### clients ############################
variable "clients_number" {
  type        = number
  description = "The number of client virtual machines to deploy."
  default     = 0
}

variable "client_instance_type" {
  type        = string
  description = "The client virtual machine type (SKU) to deploy."
  default     = "c2-standard-8"
}

variable "client_frontend_cores" {
  type        = number
  description = "The number of frontend cores allocated to client instances. This value corresponds to the number of NICs attached to each instance because each WEKA core requires its dedicated NIC."
  default     = 1
}

variable "client_source_image_id" {
  type        = string
  description = "Client Source image ID is set to Rocky 8.10. For the list of all supported Weka Client OSs please refer to: https://docs.weka.io/planning-and-installation/prerequisites-and-compatibility#operating-system"
  default     = "rocky-linux-8-v20240910"
}

variable "clients_use_dpdk" {
  type        = bool
  default     = true
  description = "Enables mounting WEKA clients in DPDK mode."
}

variable "client_nic_type" {
  type        = string
  default     = null
  description = "The type of virtual network interface (vNIC). Valid values include GVNIC and VIRTIO_NET."

  validation {
    condition     = var.client_nic_type == null || var.client_nic_type == "GVNIC" || var.client_nic_type == "VIRTIO_NET"
    error_message = "The vNIC type must be either GVNIC or VIRTIO_NET."
  }
}

variable "clients_custom_data" {
  type        = string
  description = "Custom data to pass to the client instances"
  default     = ""
}

############################################### nfs protocol gateways variables ###################################################
variable "nfs_protocol_gateways_number" {
  type        = number
  description = "The number of NFS protocol gateway virtual machines to deploy."
  default     = 0
}

variable "nfs_protocol_gateway_secondary_ips_per_nic" {
  type        = number
  description = "The number of secondary IPs per single NIC per NFS protocol gateway virtual machine."
  default     = 0

  validation {
    condition     = var.nfs_protocol_gateway_secondary_ips_per_nic == 0
    error_message = "Secondary (floating) IPs are currently not supported for GCP NFS protocol gateways."
  }
}

variable "nfs_protocol_gateway_machine_type" {
  type        = string
  description = "The virtual machine type (SKU) for the NFS protocol gateways to deploy."
  default     = "c2-standard-8"
}

variable "nfs_protocol_gateway_disk_size" {
  type        = number
  default     = 48
  description = "The default disk size for NFS protocol gateways."
}

variable "nfs_protocol_gateway_fe_cores_num" {
  type        = number
  default     = 1
  description = "The number of frontend cores on each NFS protocol gateway machine."
}

variable "nfs_setup_protocol" {
  type        = bool
  description = "Specifies whether to configure the NFS protocol."
  default     = false
}

variable "nfs_interface_group_name" {
  type        = string
  description = "Interface group name."
  default     = "weka-ig"

  validation {
    condition     = length(var.nfs_interface_group_name) <= 11
    error_message = "The interface group name should be up to 11 characters long."
  }
}

############################################### smb protocol gateways variables ###################################################
variable "smb_protocol_gateways_number" {
  type        = number
  description = "The number of virtual machines to deploy as SMB protocol gateways."
  default     = 0
}

variable "smb_protocol_gateway_secondary_ips_per_nic" {
  type        = number
  description = "Number of secondary IPs per NIC per SMB protocol gateway virtual machine."
  default     = 3
}

variable "smb_protocol_gateway_machine_type" {
  type        = string
  description = "The virtual machine type (SKU) for deploying SMB protocol gateways."
  default     = "c2-standard-8"
}

variable "smb_protocol_gateway_disk_size" {
  type        = number
  default     = 375
  description = "The default disk size for SMB protocol gateways."
}

variable "smb_protocol_gateway_fe_cores_num" {
  type        = number
  default     = 1
  description = "The number of frontend cores on each SMB protocol gateway machine."
}

variable "smb_setup_protocol" {
  type        = bool
  description = "Specifies whether to configure SMB protocol cluster."
  default     = false
}

variable "smbw_enabled" {
  type        = bool
  default     = true
  description = "Enables SMBW protocol. Allocate extra capacity for SMB-W cluster before creating the cluster."
}

variable "smb_cluster_name" {
  type        = string
  description = "The name of the SMB cluster."
  default     = "Weka-SMB"

  validation {
    condition     = length(var.smb_cluster_name) > 0 && length(var.smb_cluster_name) <= 15
    error_message = "The SMB cluster name must be between 1 and 15 characters long."
  }
}

variable "smb_domain_name" {
  type        = string
  description = "The domain to join the SMB cluster."
  default     = ""
}

############################################### s3 protocol gateways variables ###################################################
variable "s3_protocol_gateways_number" {
  type        = number
  description = "The Number of virtual machines to deploy as S3 protocol gateways."
  default     = 0
}

variable "s3_protocol_gateway_machine_type" {
  type        = string
  description = "The virtual machine type (SKU) for deploying S3 protocol gateways."
  default     = "c2-standard-8"
}

variable "s3_protocol_gateway_disk_size" {
  type        = number
  default     = 375
  description = "The default disk size for S3 protocol gateways."
}

variable "s3_protocol_gateway_fe_cores_num" {
  type        = number
  default     = 1
  description = "The number of frontend cores on each S3 protocol gateway machine."
}

variable "s3_setup_protocol" {
  type        = bool
  description = "Specifies whether to configure S3 protocol cluster."
  default     = false
}

variable "weka_home_url" {
  type        = string
  description = "The URL for WEKA Home."
  default     = ""
}

variable "vm_username" {
  type        = string
  description = "The username provided as part of the output for automated use of Terraform. Replace with the user for SSH connection in case of custom image and automated use of outputs."
  default     = "weka"
}

variable "ssh_public_key" {
  type        = string
  description = "The SSH public key to pass to VMs."
  default     = null
}

variable "vpcs_to_peer_to_deployment_vpc" {
  type        = list(string)
  description = "The list of VPC names to peer."
  default     = []
}

variable "vpcs_range_to_peer_to_deployment_vpc" {
  type        = list(string)
  description = "The list of VPC ranges to peer in CIDR format."
  default     = []
}

variable "weka_tar_bucket_name" {
  type        = string
  default     = ""
  description = "The bucket name for the WEKA software tar file."
}

variable "weka_tar_project_id" {
  type        = string
  default     = ""
  description = "The project ID for the WEKA software tar file."
}

variable "subnet_autocreate_as_private" {
  type        = bool
  default     = false
  description = "Creates a private subnet using NAT gateway to route traffic. The default is a public network. Applicable only when subnet_ids is empty."
}

variable "endpoint_vpcsc_internal_ip_address" {
  type        = string
  default     = "10.0.1.6"
  description = "The private IP address for VPC service connection endpoint."
}

variable "endpoint_apis_internal_ip_address" {
  type        = string
  default     = "10.0.1.5"
  description = "The private IP address for all-apis endpoint."
}

variable "cloud_run_dns_zone_name" {
  type        = string
  default     = ""
  description = "The name of existing private DNS zone for the domain run.app (it provides GCP hosting services)."
}

variable "googleapis_dns_zone_name" {
  type        = string
  default     = ""
  description = "The name of existing private DNS zone for domain googleapis.com."
}

variable "psc_subnet_cidr" {
  type        = string
  default     = "10.9.0.0/28"
  description = "The CIDR range for the private service connection subnet."
}

variable "create_nat_gateway" {
  type        = bool
  default     = false
  description = "Specifies whether to create a NAT gateway when no public IP is assigned to the backend, allowing internet access."
}

variable "network_project_id" {
  type        = string
  default     = ""
  description = "The project ID for the network."
}

variable "set_shared_vpc_peering" {
  type        = bool
  description = "Enables peering for shared VPC."
  default     = true
}

variable "enable_shared_vpc_host_project" {
  description = "Specifies whether the created project functions as a Shared VPC host project. If true, ensure the shared_vpc variable remains disabled (set to false)."
  type        = bool
  default     = true
}

variable "set_peering" {
  type        = bool
  description = "Specifies whether to apply peering connection between subnets."
  default     = true
}

variable "shared_vpc_project_id" {
  description = "The project ID for the shared VPC."
  type        = string
  default     = ""
}

variable "install_cluster_dpdk" {
  type        = bool
  default     = true
  description = "Specifies whether to install the WEKA cluster with DPDK."
}

variable "debug_down_backends_removal_timeout" {
  type        = string
  default     = "3h"
  description = "Timeout duration for removing non-functional backends. Specify the timeout period in time units: ns, us (or µs), ms, s, m, h. This parameter is critical for managing the removal of non-operational backend resources. Consult with the WEKA Success Team before making any changes."
}

variable "lb_allow_global_access" {
  type        = bool
  default     = false
  description = "Specifies whether to allow access to the load balancer from all regions."
}

variable "set_default_fs" {
  type        = bool
  description = "Set the default filesystem which will use the full available capacity"
  default     = true
}

variable "post_cluster_setup_script" {
  type        = string
  description = "A script to run after the cluster is up"
  default     = ""
}

variable "labels_map" {
  type        = map(string)
  default     = {}
  description = "A map of labels to assign the same metadata to all resources in the environment. Format: key:value."
}
