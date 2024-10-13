# GCP-WEKA deployment Terraform module
The GCP-WEKA Deployment Terraform module simplifies the creation of WEKA deployments on the Google Cloud Platform (GCP). It allows you to efficiently manage resources such as launch templates, cloud functions, workflows, and schedulers. Using the Terraform module establishes a process that automatically launches instances based on the specified cluster size.

<br>**Scope:** This README describes the Terraform module’s configuration files. For the introduction and deployment workflows, refer to **WEKA installation on GCP** in [WEKA documentation](https://docs.weka.io).

## Network deployment options
When deploying WEKA on GCP, you have two options for network configuration:

* Use an existing network:
<br>If you choose this option, WEKA uses your existing network resources.
These resources include Virtual Private Clouds (VPCs), subnets, security groups (firewalls), private DNS zones, and VPC access connectors.
Ensure that you provide the necessary network parameters when using an existing network.

* Automatically create network resources:
<br>Alternatively, WEKA can create the required network resources for you.
This includes setting up VPCs, subnets, security groups, private DNS zones, and VPC access connectors.

<br>Refer to the [examples](examples) for guidance.

<br>**Example of using an existing network**:
```hcl
vpcs_name           = ["vpc-0","vpc-1","vpc-2","vpc-3"]
subnets_name        = ["subnet-0","subnet-1","subnet-2","subnet-3"]
private_dns_name    = "existing.private.net."
private_zone_name   = "existing-private-zone"
vpc_connector_name  = "existing-connector"
```

## WEKA cluster deployment usage example
```hcl
module "weka_deployment" {
  source                   = "weka/weka/gcp"
  version                  = "3.0.2"
  cluster_name             = "myCluster"
  project_id               = "myProject"
  vpcs_name                = ["weka-vpc-0", "weka-vpc-1", "weka-vpc-2", "weka-vpc-3"]
  region                   = "europe-west1"
  subnets_name             = ["weka-subnet-0","weka-subnet-1","weka-subnet-2","weka-subnet-3"]
  zone                     = "europe-west1-b"
  cluster_size             = 7
  nvmes_number             = 2
  vpc_connector            = "weka-connector"
  sa_email                 = "weka-deploy-sa@myProject.iam.gserviceaccount.com"
  get_weka_io_token        = "GET_WEKA_IO_TOKEN"
  private_dns_zone         = "weka-private-zone"
  private_dns_name         = "weka.private.net."
}
```
## Deploy WEKA network on the host project
You can deploy the network on the host project and the cluster on the service project.
<br>To set up the deployment, provide the following variable:
```hcl
network_project_id = NETWORK_PROJECT_ID
```

### Enable public IP assignment
In GCP, external IP addresses are always public and can be assigned to instances. These addresses allow communication with resources outside the Virtual Private Cloud (VPC) network.
<br>**Note:** Using external IP addresses may incur additional charges.
<br> To enable public IP assignment, set:
```hcl
assign_public_ip   = true
```

### Create cloud NAT
Cloud NAT (Network Address Translation) on GCP allows instances within a private network to access the internet without requiring external IP addresses, enhancing security by keeping instances private while enabling outbound connectivity.
<br>To enable Cloud NAT, set:
```hcl
create_nat_gateway = true
```

## Object Storage Service (OBS) tiering
WEKA supports tiering to buckets. To configure tiering, add the following variables:
```hcl
tiering_enable_obs_integration = true
tiering_obs_name               = "..."
tiering_enable_ssd_percent     = 20
```

## Automatic client creation and mounting
WEKA enables automatic client creation and mounting. Specify the number of clients you need (default is 0).
<br>For example, to create two clients, add the following:
```hcl
clients_number = 2
```

<br>You can also define the client instance type and the number of allocated cores with the following variables:
```hcl
client_instance_type = "c2-standard-8"
client_frontend_cores = DESIRED_NUM
```
### UDP mode for client mounting
To mount the clients in UDP mode, add the following:
```hcl
clients_use_dpdk = false
```

## NFS protocol gateways
WEKA supports the creation of NFS protocol gateways that automatically mount to the cluster. Specify the number of instances (default is 0).

Example:
```hcl
nfs_protocol_gateways_number = 2
```

<br>Additional optional variables include:
```hcl
nfs_protocol_gateway_machine_type  = "c2-standard-8"
nfs_protocol_gateway_disk_size     = 48
nfs_protocol_gateway_fe_cores_num  = 1
nfs_setup_protocol                 = true
```

## S3 protocol gateways
WEKA supports the creation of S3 protocol gateways that automatically mount to the cluster. Specify the number of instances (default is 0).

Example:
```hcl
s3_protocol_gateways_number = 1
```

<br>Additional optional variables include:
```hcl
s3_protocol_gateway_machine_type    = "c2-standard-8"
s3_protocol_gateway_disk_size       = 48
s3_protocol_gateway_fe_cores_num    = 1
s3_setup_protocol                   = true
```

## SMB protocol gateways
WEKA supports the creation of SMB protocol gateways that automatically mount to the cluster. A minimum of three instances is required (default is 0).

</br>Example:
```hcl
smb_protocol_gateways_number = 3
```

<br>Additional optional variables include:
```hcl
smb_protocol_gateway_machine_type   = "c2-standard-8"
smb_protocol_gateway_disk_size      = 48
smb_protocol_gateway_fe_cores_num   = 1
smb_setup_protocol                  = true
smb_cluster_name                    = ""
smb_domain_name                     = ""
```
**Join an SMB cluster in the Active Directory**
To join an SMB cluster in the Active Directory, run this command manually:
`weka smb domain join <smb_domain_username> <smb_domain_password> [--server smb_server_name]`.

## Shared project configuration
Shared VPC (Virtual Private Cloud) lets you connect resources from multiple projects to a common VPC network. It’s a way to share network resources securely and efficiently. The host project defines the network and service projects attached to it, allowing eligible resources to use the shared network.
<br>To enable the use of Shared VPC, provide the following variables:
```hcl
shared_vpcs                    = [".."]
host_project                   = HOST_PROJECT_ID
host_shared_range              = [".."]
shared_vpc_project_id          = SHARED_VPC_PROJECT_ID
```

<br>To enable the project as a host project, provide the following variable:
```hcl
enable_shared_vpc_host_project = true
```

<br>To enable VPC network peering between the host project and the service project, provide the following variable:
```hcl
set_shared_vpc_peering = true
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.3.1 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~>2.4.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >=4.38.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~>2.4.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~>0.9.1 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~>4.0.4 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | ~>2.4.0 |
| <a name="provider_google"></a> [google](#provider\_google) | >=4.38.0 |
| <a name="provider_local"></a> [local](#provider\_local) | ~>2.4.0 |
| <a name="provider_time"></a> [time](#provider\_time) | ~>0.9.1 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | ~>4.0.4 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_clients"></a> [clients](#module\_clients) | ./modules/clients | n/a |
| <a name="module_network"></a> [network](#module\_network) | ./modules/network | n/a |
| <a name="module_nfs_protocol_gateways"></a> [nfs\_protocol\_gateways](#module\_nfs\_protocol\_gateways) | ./modules/protocol_gateways | n/a |
| <a name="module_peering"></a> [peering](#module\_peering) | ./modules/vpc_peering | n/a |
| <a name="module_s3_protocol_gateways"></a> [s3\_protocol\_gateways](#module\_s3\_protocol\_gateways) | ./modules/protocol_gateways | n/a |
| <a name="module_service_account"></a> [service\_account](#module\_service\_account) | ./modules/service_account | n/a |
| <a name="module_shared_vpc_peering"></a> [shared\_vpc\_peering](#module\_shared\_vpc\_peering) | ./modules/shared_vpcs | n/a |
| <a name="module_smb_protocol_gateways"></a> [smb\_protocol\_gateways](#module\_smb\_protocol\_gateways) | ./modules/protocol_gateways | n/a |
| <a name="module_worker_pool"></a> [worker\_pool](#module\_worker\_pool) | ./modules/worker_pool | n/a |

## Resources

| Name | Type |
|------|------|
| [google_cloud_scheduler_job.scale_down_job](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_scheduler_job) | resource |
| [google_cloud_scheduler_job.scale_up_job](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_scheduler_job) | resource |
| [google_cloudfunctions2_function.cloud_internal_function](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions2_function) | resource |
| [google_cloudfunctions2_function.scale_down_function](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions2_function) | resource |
| [google_cloudfunctions2_function.status_function](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions2_function) | resource |
| [google_cloudfunctions2_function_iam_member.cloud_internal_invoker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions2_function_iam_member) | resource |
| [google_cloudfunctions2_function_iam_member.status_invoker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions2_function_iam_member) | resource |
| [google_cloudfunctions2_function_iam_member.weka_internal_invoker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions2_function_iam_member) | resource |
| [google_compute_forwarding_rule.google_compute_forwarding_rule](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_forwarding_rule) | resource |
| [google_compute_forwarding_rule.ui_forwarding_rule](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_forwarding_rule) | resource |
| [google_compute_instance_group.nfs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_group) | resource |
| [google_compute_instance_group.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_group) | resource |
| [google_compute_instance_template.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template) | resource |
| [google_compute_region_backend_service.backend_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service) | resource |
| [google_compute_region_backend_service.ui_backend_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service) | resource |
| [google_compute_region_health_check.health_check](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_health_check) | resource |
| [google_compute_region_health_check.ui_check](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_health_check) | resource |
| [google_dns_record_set.record_a](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_dns_record_set.ui_record_a](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_eventarc_trigger.scale_down_trigger](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/eventarc_trigger) | resource |
| [google_eventarc_trigger.scale_up_trigger](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/eventarc_trigger) | resource |
| [google_project_iam_member.cloudscheduler](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.artifactregistry_api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.cloud_build_api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.compute_api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.eventarc_api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.project_function_api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.run_api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.secret_manager](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.service_scheduler_api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.service_usage_api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.workflows](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_pubsub_topic.scale_down_trigger_topic](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |
| [google_pubsub_topic.scale_up_trigger_topic](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |
| [google_secret_manager_secret.secret_token](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.secret_weka_password](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.secret_weka_username](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.weka_deployment_password](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret_version.password_secret_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.token_secret_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.user_secret_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_storage_bucket.weka_deployment](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_object.cloud_functions_zip](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |
| [google_storage_bucket_object.nfs_state](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |
| [google_storage_bucket_object.state](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |
| [google_workflows_workflow.scale_down](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/workflows_workflow) | resource |
| [google_workflows_workflow.scale_up](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/workflows_workflow) | resource |
| [local_file.private_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.public_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [time_sleep.wait_120_seconds](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [tls_private_key.ssh_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [archive_file.function_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [google_client_openid_userinfo.user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_openid_userinfo) | data source |
| [google_compute_network.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_compute_subnetwork.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_project.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_ssh_cidrs"></a> [allow\_ssh\_cidrs](#input\_allow\_ssh\_cidrs) | List of CIDR blocks allowed for SSH access (port 22). If empty, SSH access is restricted to all sources (not recommended for production). Example: Allow access from specific IP addresses: allow\_ssh\_cidrs = ["10.0.0.1/32", "192.168.1.0/24"] | `list(string)` | `[]` | no |
| <a name="input_allow_weka_api_cidrs"></a> [allow\_weka\_api\_cidrs](#input\_allow\_weka\_api\_cidrs) | List of CIDR blocks allowed for WEKA API access (port 14000). By default, no connections are allowed to port 14000. Specifying CIDRs here restricts access to the WEKA API on its backends and load balancer (if it exists and shares the security group) to the listed sources only. All ports (including 14000) are allowed within the VPC by default. | `list(string)` | `[]` | no |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Controls public IP assignment for deployed instances (backends, clients, and gateways). | `string` | `"auto"` | no |
| <a name="input_boot_disk_type"></a> [boot\_disk\_type](#input\_boot\_disk\_type) | The boot disk type. | `string` | `"pd-standard"` | no |
| <a name="input_client_frontend_cores"></a> [client\_frontend\_cores](#input\_client\_frontend\_cores) | The number of frontend cores allocated to client instances. This value corresponds to the number of NICs attached to each instance because each WEKA core requires its dedicated NIC. | `number` | `1` | no |
| <a name="input_client_instance_type"></a> [client\_instance\_type](#input\_client\_instance\_type) | The client virtual machine type (SKU) to deploy. | `string` | `"c2-standard-8"` | no |
| <a name="input_client_nic_type"></a> [client\_nic\_type](#input\_client\_nic\_type) | The type of virtual network interface (vNIC). Valid values include GVNIC and VIRTIO\_NET. | `string` | `null` | no |
| <a name="input_client_source_image_id"></a> [client\_source\_image\_id](#input\_client\_source\_image\_id) | Client Source image ID is set to Rocky 8.10. For the list of all supported Weka Client OSs please refer to: https://docs.weka.io/planning-and-installation/prerequisites-and-compatibility#operating-system | `string` | `"projects/weka-dist/global/images/weka-custom-image-rocky8-1728382317"` | no |
| <a name="input_clients_custom_data"></a> [clients\_custom\_data](#input\_clients\_custom\_data) | Custom data to pass to the client instances | `string` | `""` | no |
| <a name="input_clients_number"></a> [clients\_number](#input\_clients\_number) | The number of client virtual machines to deploy. | `number` | `0` | no |
| <a name="input_clients_use_dpdk"></a> [clients\_use\_dpdk](#input\_clients\_use\_dpdk) | Enables mounting WEKA clients in DPDK mode. | `bool` | `true` | no |
| <a name="input_cloud_functions_region_map"></a> [cloud\_functions\_region\_map](#input\_cloud\_functions\_region\_map) | Defines a mapping between regions lacking Cloud Functions functionality and alternative regions. It ensures Cloud Functions availability by redirecting workflows to supported regions when necessary. | `map(string)` | <pre>{<br>  "asia-south2": "asia-south1",<br>  "europe-north1": "europe-west1",<br>  "europe-west4": "europe-west1",<br>  "southamerica-west1": "northamerica-northeast1",<br>  "us-east5": "us-east1"<br>}</pre> | no |
| <a name="input_cloud_run_dns_zone_name"></a> [cloud\_run\_dns\_zone\_name](#input\_cloud\_run\_dns\_zone\_name) | The name of existing private DNS zone for the domain run.app (it provides GCP hosting services). | `string` | `""` | no |
| <a name="input_cloud_scheduler_region_map"></a> [cloud\_scheduler\_region\_map](#input\_cloud\_scheduler\_region\_map) | Defines a mapping between regions lacking Cloud Scheduler functionality and alternative regions. It ensures Cloud Scheduler functionality by redirecting workflows to supported regions when necessary. | `map(string)` | <pre>{<br>  "asia-south2": "asia-south1",<br>  "europe-north1": "europe-west1",<br>  "europe-west4": "europe-west1",<br>  "southamerica-west1": "northamerica-northeast1",<br>  "us-east5": "us-east1"<br>}</pre> | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster name prefix for all resources. | `string` | n/a | yes |
| <a name="input_cluster_size"></a> [cluster\_size](#input\_cluster\_size) | The number of instances deployed for your WEKA cluster. | `number` | n/a | yes |
| <a name="input_containers_config_map"></a> [containers\_config\_map](#input\_containers\_config\_map) | Defines a mapping of WEKA processes, NICs, and memory specifications for machine types. | <pre>map(object({<br>    compute  = number<br>    drive    = number<br>    frontend = number<br>    nics     = number<br>    memory   = list(string)<br>  }))</pre> | <pre>{<br>  "c2-standard-16": {<br>    "compute": 4,<br>    "drive": 1,<br>    "frontend": 1,<br>    "memory": [<br>      "24.2GB",<br>      "23.2GB"<br>    ],<br>    "nics": 7<br>  },<br>  "c2-standard-8": {<br>    "compute": 1,<br>    "drive": 1,<br>    "frontend": 1,<br>    "memory": [<br>      "4.2GB",<br>      "4GB"<br>    ],<br>    "nics": 4<br>  },<br>  "n2-standard-16": {<br>    "compute": 4,<br>    "drive": 1,<br>    "frontend": 1,<br>    "memory": [<br>      "18.9GB",<br>      "18.9GB"<br>    ],<br>    "nics": 7<br>  },<br>  "n2-standard-8": {<br>    "compute": 1,<br>    "drive": 1,<br>    "frontend": 1,<br>    "memory": [<br>      "3.1GB",<br>      "1.6GB"<br>    ],<br>    "nics": 4<br>  }<br>}</pre> | no |
| <a name="input_create_cloudscheduler_sa"></a> [create\_cloudscheduler\_sa](#input\_create\_cloudscheduler\_sa) | Enables creation of a Cloud Scheduler service account. Set this to false to reuse an existing service account for Cloud Scheduler jobs. | `bool` | `true` | no |
| <a name="input_create_nat_gateway"></a> [create\_nat\_gateway](#input\_create\_nat\_gateway) | Specifies whether to create a NAT gateway when no public IP is assigned to the backend, allowing internet access. | `bool` | `false` | no |
| <a name="input_create_worker_pool"></a> [create\_worker\_pool](#input\_create\_worker\_pool) | Determines whether to create a worker pool. Set to true if a worker pool is needed. | `bool` | `false` | no |
| <a name="input_debug_down_backends_removal_timeout"></a> [debug\_down\_backends\_removal\_timeout](#input\_debug\_down\_backends\_removal\_timeout) | Timeout duration for removing non-functional backends. Specify the timeout period in time units: ns, us (or µs), ms, s, m, h. This parameter is critical for managing the removal of non-operational backend resources. Consult with the WEKA Success Team before making any changes. | `string` | `"3h"` | no |
| <a name="input_default_disk_name"></a> [default\_disk\_name](#input\_default\_disk\_name) | The default disk name. | `string` | `"wekaio-volume"` | no |
| <a name="input_default_disk_size"></a> [default\_disk\_size](#input\_default\_disk\_size) | The default disk size. | `number` | `48` | no |
| <a name="input_dns_zone_project_id"></a> [dns\_zone\_project\_id](#input\_dns\_zone\_project\_id) | Project ID for the DNS zone. If omitted, it uses network project ID or falls back to project ID. | `string` | `""` | no |
| <a name="input_enable_shared_vpc_host_project"></a> [enable\_shared\_vpc\_host\_project](#input\_enable\_shared\_vpc\_host\_project) | Specifies whether the created project functions as a Shared VPC host project. If true, ensure the shared\_vpc variable remains disabled (set to false). | `bool` | `true` | no |
| <a name="input_endpoint_apis_internal_ip_address"></a> [endpoint\_apis\_internal\_ip\_address](#input\_endpoint\_apis\_internal\_ip\_address) | The private IP address for all-apis endpoint. | `string` | `"10.0.1.5"` | no |
| <a name="input_endpoint_vpcsc_internal_ip_address"></a> [endpoint\_vpcsc\_internal\_ip\_address](#input\_endpoint\_vpcsc\_internal\_ip\_address) | The private IP address for VPC service connection endpoint. | `string` | `"10.0.1.6"` | no |
| <a name="input_get_weka_io_token"></a> [get\_weka\_io\_token](#input\_get\_weka\_io\_token) | WEKA software download token. Obtain a valid token from https://get.weka.io/ to download and install the WEKA software during deployment. | `string` | `""` | no |
| <a name="input_googleapis_dns_zone_name"></a> [googleapis\_dns\_zone\_name](#input\_googleapis\_dns\_zone\_name) | The name of existing private DNS zone for domain googleapis.com. | `string` | `""` | no |
| <a name="input_host_project"></a> [host\_project](#input\_host\_project) | The ID of the project that acts as a shared VPC host project. | `string` | `""` | no |
| <a name="input_host_shared_range"></a> [host\_shared\_range](#input\_host\_shared\_range) | List of host ranges to allow security groups. | `list(string)` | `[]` | no |
| <a name="input_hotspare"></a> [hotspare](#input\_hotspare) | A hot spare is the system's ability to withstand the loss of a defined number of failure domains, rebuild data completely, and maintain original net capacity. | `number` | `1` | no |
| <a name="input_install_cluster_dpdk"></a> [install\_cluster\_dpdk](#input\_install\_cluster\_dpdk) | Specifies whether to install the WEKA cluster with DPDK. | `bool` | `true` | no |
| <a name="input_install_weka_url"></a> [install\_weka\_url](#input\_install\_weka\_url) | The URL to WEKA installation script or tar object. Examples: URL to installation script: https://TOKEN@get.weka.io/dist/v1/install/4.3.1/4.3.1. URL to tar object: https://TOKEN@get.weka.io/dist/v1/pkg/weka-4.3.1.tar. URL to tar object in a cloud bucket: gs://weka-installation/weka-4.2.12.87.tar. (Replace TOKEN with your valid WEKA download token). | `string` | `""` | no |
| <a name="input_lb_allow_global_access"></a> [lb\_allow\_global\_access](#input\_lb\_allow\_global\_access) | Specifies whether to allow access to the load balancer from all regions. | `bool` | `false` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | The machine type for the WEKA backend instance. | `string` | `"c2-standard-8"` | no |
| <a name="input_mtu_size"></a> [mtu\_size](#input\_mtu\_size) | The Maximum Transmission Unit (MTU) size is the largest packet size that can be transmitted over a network. | `number` | `8896` | no |
| <a name="input_network_project_id"></a> [network\_project\_id](#input\_network\_project\_id) | The project ID for the network. | `string` | `""` | no |
| <a name="input_nfs_interface_group_name"></a> [nfs\_interface\_group\_name](#input\_nfs\_interface\_group\_name) | Interface group name. | `string` | `"weka-ig"` | no |
| <a name="input_nfs_protocol_gateway_disk_size"></a> [nfs\_protocol\_gateway\_disk\_size](#input\_nfs\_protocol\_gateway\_disk\_size) | The default disk size for NFS protocol gateways. | `number` | `48` | no |
| <a name="input_nfs_protocol_gateway_fe_cores_num"></a> [nfs\_protocol\_gateway\_fe\_cores\_num](#input\_nfs\_protocol\_gateway\_fe\_cores\_num) | The number of frontend cores on each NFS protocol gateway machine. | `number` | `1` | no |
| <a name="input_nfs_protocol_gateway_machine_type"></a> [nfs\_protocol\_gateway\_machine\_type](#input\_nfs\_protocol\_gateway\_machine\_type) | The virtual machine type (SKU) for the NFS protocol gateways to deploy. | `string` | `"c2-standard-8"` | no |
| <a name="input_nfs_protocol_gateway_secondary_ips_per_nic"></a> [nfs\_protocol\_gateway\_secondary\_ips\_per\_nic](#input\_nfs\_protocol\_gateway\_secondary\_ips\_per\_nic) | The number of secondary IPs per single NIC per NFS protocol gateway virtual machine. | `number` | `0` | no |
| <a name="input_nfs_protocol_gateways_number"></a> [nfs\_protocol\_gateways\_number](#input\_nfs\_protocol\_gateways\_number) | The number of NFS protocol gateway virtual machines to deploy. | `number` | `0` | no |
| <a name="input_nfs_setup_protocol"></a> [nfs\_setup\_protocol](#input\_nfs\_setup\_protocol) | Specifies whether to configure the NFS protocol. | `bool` | `false` | no |
| <a name="input_nic_number"></a> [nic\_number](#input\_nic\_number) | Number of NICs per host. | `number` | `-1` | no |
| <a name="input_nic_type"></a> [nic\_type](#input\_nic\_type) | The type of vNIC. Possible values: GVNIC, VIRTIO\_NET. | `string` | `null` | no |
| <a name="input_nvmes_number"></a> [nvmes\_number](#input\_nvmes\_number) | Number of NVMe disks to attach to each host. | `number` | `2` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix for all resources (maximum 15 characters). | `string` | `"weka"` | no |
| <a name="input_private_dns_name"></a> [private\_dns\_name](#input\_private\_dns\_name) | Private DNS name. | `string` | `""` | no |
| <a name="input_private_zone_name"></a> [private\_zone\_name](#input\_private\_zone\_name) | Private zone name. | `string` | `""` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id | `string` | n/a | yes |
| <a name="input_protection_level"></a> [protection\_level](#input\_protection\_level) | The protection level, referring to the cluster data, indicates the number of additional protection blocks per stripe, either 2 or 4. | `number` | `2` | no |
| <a name="input_proxy_url"></a> [proxy\_url](#input\_proxy\_url) | The URL for the WEKA Home proxy. | `string` | `""` | no |
| <a name="input_psc_subnet_cidr"></a> [psc\_subnet\_cidr](#input\_psc\_subnet\_cidr) | The CIDR range for the private service connection subnet. | `string` | `"10.9.0.0/28"` | no |
| <a name="input_region"></a> [region](#input\_region) | GCP region, a broader geographic area within GCP that houses your resources. It encompasses multiple zones. | `string` | n/a | yes |
| <a name="input_s3_protocol_gateway_disk_size"></a> [s3\_protocol\_gateway\_disk\_size](#input\_s3\_protocol\_gateway\_disk\_size) | The default disk size for S3 protocol gateways. | `number` | `375` | no |
| <a name="input_s3_protocol_gateway_fe_cores_num"></a> [s3\_protocol\_gateway\_fe\_cores\_num](#input\_s3\_protocol\_gateway\_fe\_cores\_num) | The number of frontend cores on each S3 protocol gateway machine. | `number` | `1` | no |
| <a name="input_s3_protocol_gateway_machine_type"></a> [s3\_protocol\_gateway\_machine\_type](#input\_s3\_protocol\_gateway\_machine\_type) | The virtual machine type (SKU) for deploying S3 protocol gateways. | `string` | `"c2-standard-8"` | no |
| <a name="input_s3_protocol_gateways_number"></a> [s3\_protocol\_gateways\_number](#input\_s3\_protocol\_gateways\_number) | The Number of virtual machines to deploy as S3 protocol gateways. | `number` | `0` | no |
| <a name="input_s3_setup_protocol"></a> [s3\_setup\_protocol](#input\_s3\_setup\_protocol) | Specifies whether to configure S3 protocol cluster. | `bool` | `false` | no |
| <a name="input_sa_email"></a> [sa\_email](#input\_sa\_email) | Email address of an existing service account to be used. Leave blank to create a new service account during deployment. | `string` | `""` | no |
| <a name="input_set_dedicated_fe_container"></a> [set\_dedicated\_fe\_container](#input\_set\_dedicated\_fe\_container) | Creates a cluster with dedicated frontend containers. | `bool` | `false` | no |
| <a name="input_set_peering"></a> [set\_peering](#input\_set\_peering) | Specifies whether to apply peering connection between subnets. | `bool` | `true` | no |
| <a name="input_set_shared_vpc_peering"></a> [set\_shared\_vpc\_peering](#input\_set\_shared\_vpc\_peering) | Enables peering for shared VPC. | `bool` | `true` | no |
| <a name="input_shared_vpc_project_id"></a> [shared\_vpc\_project\_id](#input\_shared\_vpc\_project\_id) | The project ID for the shared VPC. | `string` | `""` | no |
| <a name="input_shared_vpcs"></a> [shared\_vpcs](#input\_shared\_vpcs) | list of shared vpc names. | `list(string)` | `[]` | no |
| <a name="input_smb_cluster_name"></a> [smb\_cluster\_name](#input\_smb\_cluster\_name) | The name of the SMB cluster. | `string` | `"Weka-SMB"` | no |
| <a name="input_smb_domain_name"></a> [smb\_domain\_name](#input\_smb\_domain\_name) | The domain to join the SMB cluster. | `string` | `""` | no |
| <a name="input_smb_protocol_gateway_disk_size"></a> [smb\_protocol\_gateway\_disk\_size](#input\_smb\_protocol\_gateway\_disk\_size) | The default disk size for SMB protocol gateways. | `number` | `375` | no |
| <a name="input_smb_protocol_gateway_fe_cores_num"></a> [smb\_protocol\_gateway\_fe\_cores\_num](#input\_smb\_protocol\_gateway\_fe\_cores\_num) | The number of frontend cores on each SMB protocol gateway machine. | `number` | `1` | no |
| <a name="input_smb_protocol_gateway_machine_type"></a> [smb\_protocol\_gateway\_machine\_type](#input\_smb\_protocol\_gateway\_machine\_type) | The virtual machine type (SKU) for deploying SMB protocol gateways. | `string` | `"c2-standard-8"` | no |
| <a name="input_smb_protocol_gateway_secondary_ips_per_nic"></a> [smb\_protocol\_gateway\_secondary\_ips\_per\_nic](#input\_smb\_protocol\_gateway\_secondary\_ips\_per\_nic) | Number of secondary IPs per NIC per SMB protocol gateway virtual machine. | `number` | `3` | no |
| <a name="input_smb_protocol_gateways_number"></a> [smb\_protocol\_gateways\_number](#input\_smb\_protocol\_gateways\_number) | The number of virtual machines to deploy as SMB protocol gateways. | `number` | `0` | no |
| <a name="input_smb_setup_protocol"></a> [smb\_setup\_protocol](#input\_smb\_setup\_protocol) | Specifies whether to configure SMB protocol cluster. | `bool` | `false` | no |
| <a name="input_smbw_enabled"></a> [smbw\_enabled](#input\_smbw\_enabled) | Enables SMBW protocol. Allocate extra capacity for SMB-W cluster before creating the cluster. | `bool` | `true` | no |
| <a name="input_source_image_id"></a> [source\_image\_id](#input\_source\_image\_id) | Source image for deployment (default: weka-custom-image-rocky8-1728382317). While other distributions may be compatible, only Rocky Linux 8.10 is officially tested with this Terraform module. | `string` | `"projects/weka-dist/global/images/weka-custom-image-rocky8-1728382317"` | no |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | The SSH public key to pass to VMs. | `string` | `null` | no |
| <a name="input_state_bucket_name"></a> [state\_bucket\_name](#input\_state\_bucket\_name) | The name of a bucket used for state storage in the cloud. | `string` | `""` | no |
| <a name="input_stripe_width"></a> [stripe\_width](#input\_stripe\_width) | The stripe width is the number of blocks sharing a common protection set, which ranges from 3 to 16. By default, stripe\_width = cluster\_size - protection\_level - 1. The default value -1 means the stripe size is calculated automatically; otherwise, the specified value is used. | `number` | `-1` | no |
| <a name="input_subnet_autocreate_as_private"></a> [subnet\_autocreate\_as\_private](#input\_subnet\_autocreate\_as\_private) | Creates a private subnet using NAT gateway to route traffic. The default is a public network. Applicable only when subnet\_ids is empty. | `bool` | `false` | no |
| <a name="input_subnets_name"></a> [subnets\_name](#input\_subnets\_name) | List of names (0, 4, or 7) for subnets defined in the subnets\_range variable. | `list(string)` | `[]` | no |
| <a name="input_subnets_range"></a> [subnets\_range](#input\_subnets\_range) | List of subnet CIDRs (0, 4, or 7) for cluster creation. 0: No subnets (for single-node testing). 4: Common setup for production (spread across AZs for redundancy). 7: Less common deployments with specific needs. | `list(string)` | <pre>[<br>  "10.0.0.0/24",<br>  "10.1.0.0/24",<br>  "10.2.0.0/24",<br>  "10.3.0.0/24"<br>]</pre> | no |
| <a name="input_tiering_enable_obs_integration"></a> [tiering\_enable\_obs\_integration](#input\_tiering\_enable\_obs\_integration) | Controls integration with object stores in the WEKA cluster for tiering. Set to true to enable this integration. | `bool` | `false` | no |
| <a name="input_tiering_enable_ssd_percent"></a> [tiering\_enable\_ssd\_percent](#input\_tiering\_enable\_ssd\_percent) | When the OBS integration setting is enabled, this parameter sets the percentage of the filesystem capacity that resides on the SSD. For example, if this parameter is set to 20 (percent) and the total available SSD capacity is 20GB, the total capacity is 100 GB. | `number` | `20` | no |
| <a name="input_tiering_obs_name"></a> [tiering\_obs\_name](#input\_tiering\_obs\_name) | The name of the OBS cloud storage used for tiering. | `string` | `""` | no |
| <a name="input_tiering_obs_start_demote"></a> [tiering\_obs\_start\_demote](#input\_tiering\_obs\_start\_demote) | Target tiering cue (in seconds) before starting upload data to OBS (turning it into read cache). Default is 10 seconds. | `number` | `10` | no |
| <a name="input_tiering_obs_target_ssd_retention"></a> [tiering\_obs\_target\_ssd\_retention](#input\_tiering\_obs\_target\_ssd\_retention) | Target retention period (in seconds) before tiering to OBS (how long data will stay in SSD). Default is 86400 seconds (24 hours). | `number` | `86400` | no |
| <a name="input_traces_per_ionode"></a> [traces\_per\_ionode](#input\_traces\_per\_ionode) | The number of traces generated per ionode. Traces represent low-level events generated by WEKA processes and are used for support. | `number` | `10` | no |
| <a name="input_vm_username"></a> [vm\_username](#input\_vm\_username) | The username provided as part of the output for automated use of Terraform. Replace with the user for SSH connection in case of custom image and automated use of outputs. | `string` | `"weka"` | no |
| <a name="input_vpc_connector_egress_settings"></a> [vpc\_connector\_egress\_settings](#input\_vpc\_connector\_egress\_settings) | Egress settings for the VPC connector. Possible values: ALL\_TRAFFIC, PRIVATE\_RANGES\_ONLY. | `string` | `"PRIVATE_RANGES_ONLY"` | no |
| <a name="input_vpc_connector_id"></a> [vpc\_connector\_id](#input\_vpc\_connector\_id) | ID of an existing VPC connector for serverless VPC access in the format: projects/<project-id>/locations/<region>/connectors/<connector-name>. Leave blank to create a new VPC connector during deployment. | `string` | `""` | no |
| <a name="input_vpc_connector_range"></a> [vpc\_connector\_range](#input\_vpc\_connector\_range) | VPC connector CIDR block for serverless VPC access. | `string` | `"10.8.0.0/28"` | no |
| <a name="input_vpcs_name"></a> [vpcs\_name](#input\_vpcs\_name) | Names of VPC networks to associate with the resource. Depending on your configuration, you can specify 0, 4, or 7 VPC networks. | `list(string)` | `[]` | no |
| <a name="input_vpcs_range_to_peer_to_deployment_vpc"></a> [vpcs\_range\_to\_peer\_to\_deployment\_vpc](#input\_vpcs\_range\_to\_peer\_to\_deployment\_vpc) | The list of VPC ranges to peer in CIDR format. | `list(string)` | `[]` | no |
| <a name="input_vpcs_to_peer_to_deployment_vpc"></a> [vpcs\_to\_peer\_to\_deployment\_vpc](#input\_vpcs\_to\_peer\_to\_deployment\_vpc) | The list of VPC names to peer. | `list(string)` | `[]` | no |
| <a name="input_weka_home_url"></a> [weka\_home\_url](#input\_weka\_home\_url) | The URL for WEKA Home. | `string` | `""` | no |
| <a name="input_weka_tar_bucket_name"></a> [weka\_tar\_bucket\_name](#input\_weka\_tar\_bucket\_name) | The bucket name for the WEKA software tar file. | `string` | `""` | no |
| <a name="input_weka_tar_project_id"></a> [weka\_tar\_project\_id](#input\_weka\_tar\_project\_id) | The project ID for the WEKA software tar file. | `string` | `""` | no |
| <a name="input_weka_version"></a> [weka\_version](#input\_weka\_version) | WEKA version | `string` | `""` | no |
| <a name="input_worker_address_prefix_length"></a> [worker\_address\_prefix\_length](#input\_worker\_address\_prefix\_length) | The prefix length for IP addresses, expressed in the worker\_pool\_address\_cidr. For example, use 24 for a /24 subnet or 16 for a /16 subnet. The maximum value is 24. | `string` | `"16"` | no |
| <a name="input_worker_disk_size"></a> [worker\_disk\_size](#input\_worker\_disk\_size) | The size of the disk attached to the worker node in GB. | `number` | `100` | no |
| <a name="input_worker_machine_type"></a> [worker\_machine\_type](#input\_worker\_machine\_type) | The machine type for a worker. | `string` | `"e2-standard-4"` | no |
| <a name="input_worker_pool_address_cidr"></a> [worker\_pool\_address\_cidr](#input\_worker\_pool\_address\_cidr) | The address range for worker machines within a Cloud Build Private Pool. It follows CIDR notation excluding the prefix length. | `string` | `"10.37.0.0"` | no |
| <a name="input_worker_pool_id"></a> [worker\_pool\_id](#input\_worker\_pool\_id) | The unique identifier for the worker pool. The worker pool must belong to the same project and region. If left empty, the default worker pool is used. | `string` | `""` | no |
| <a name="input_workflow_map_region"></a> [workflow\_map\_region](#input\_workflow\_map\_region) | Defines a mapping between regions lacking Cloud Workflows functionality and alternative regions. It ensures Cloud Workflows functionality by redirecting workflows to supported regions when necessary. | `map(string)` | <pre>{<br>  "southamerica-west1": "southamerica-east1"<br>}</pre> | no |
| <a name="input_yum_repo_server"></a> [yum\_repo\_server](#input\_yum\_repo\_server) | URL of a Yum repository server for package installation. Leave blank to use the default repositories. | `string` | `""` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | GCP zone, which is a deployment area within a region, providing physical separation for your resources. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backend_lb_ip"></a> [backend\_lb\_ip](#output\_backend\_lb\_ip) | The backend load balancer ip address. |
| <a name="output_client_ips"></a> [client\_ips](#output\_client\_ips) | If 'assign\_public\_ip' is set to true, it will output clients public ips, otherwise private ips. |
| <a name="output_cluster_helper_commands"></a> [cluster\_helper\_commands](#output\_cluster\_helper\_commands) | Useful commands and script to interact with weka cluster |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The cluster name |
| <a name="output_functions_url"></a> [functions\_url](#output\_functions\_url) | Functions url and body for api request |
| <a name="output_get_cluster_status_uri"></a> [get\_cluster\_status\_uri](#output\_get\_cluster\_status\_uri) | URL of status function |
| <a name="output_lb_url"></a> [lb\_url](#output\_lb\_url) | URL of LB |
| <a name="output_nfs_protocol_gateways_ips"></a> [nfs\_protocol\_gateways\_ips](#output\_nfs\_protocol\_gateways\_ips) | Ips of NFS protocol gateways |
| <a name="output_private_ssh_key"></a> [private\_ssh\_key](#output\_private\_ssh\_key) | private\_ssh\_key:  If 'ssh\_public\_key' is set to null, it will output the private ssh key location. |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | Project ID |
| <a name="output_resize_cluster_uri"></a> [resize\_cluster\_uri](#output\_resize\_cluster\_uri) | URL of resize function |
| <a name="output_s3_protocol_gateways_ips"></a> [s3\_protocol\_gateways\_ips](#output\_s3\_protocol\_gateways\_ips) | Ips of S3 protocol gateways |
| <a name="output_smb_protocol_gateways_ips"></a> [smb\_protocol\_gateways\_ips](#output\_smb\_protocol\_gateways\_ips) | Ips of SMB protocol gateways |
| <a name="output_terminate_cluster_uri"></a> [terminate\_cluster\_uri](#output\_terminate\_cluster\_uri) | URL of terminate function |
| <a name="output_vm_username"></a> [vm\_username](#output\_vm\_username) | Provided as part of output for automated use of terraform, ssh user to weka cluster vm |
| <a name="output_weka_cluster_admin_password_secret_id"></a> [weka\_cluster\_admin\_password\_secret\_id](#output\_weka\_cluster\_admin\_password\_secret\_id) | Secret id of weka cluster admin password |
<!-- END_TF_DOCS -->
