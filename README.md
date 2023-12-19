# GCP weka deployment Terraform module
Terraform module that creates weka deployments.
This module creates many resources as launch template, cloud functions, workflows, cloud scheduler etc.
<br>**Note**: when applying this module it will create a workflow that will automatically starts instances according to the
given cluster size.

## Network deployment options
This weka deployment can use existing network, or create network resources (vpcs, subnets, firewall(security group_, private DNS zone, vpc access connector) automatically.
<br>Check our [examples](examples).
<br>In case you want to use an existing network, you **must** provide network params.
<br>**Example**:
```hcl
vpcs_name           = ["vpc-0","vpc-1","vpc-2","vpc-3"]
subnets_name        = ["subnet-0","subnet-1","subnet-2","subnet-3"]
private_dns_name    = "existing.private.net."
private_zone_name   = "existing-private-zone"
vpc_connector_name  = "existing-connector"
```

## Usage
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
## Deploy weka network on host project
We support creating network on host project and deployment cluster on service project
In order to setup, you must provide the following variable:
```hcl
network_project_id = NETWORK_PROJECT_ID
```

## OBS
We support tiering to bucket.
In order to setup tiering, you must provide the following variables:
```hcl
tiering_enable_obs_integration = true
tiering_obs_name               = "..."
tiering_ssd_percent            = 20
```

## Clients
We support creating clients that will be mounted automatically to the cluster.
<br>In order to create clients you need to provide the number of clients you want (by default the number is 0),
for example:
```hcl
clients_number = 2
```
This will automatically create 2 clients.
<br>In addition you can provide these optional variables:
```hcl
client_instance_type = "c2-standard-8"
client_frontend_cores = DESIRED_NUM
```
### Mounting clients in udp mode
In order to mount clients in UDP mode you should pass the following param (in addition to the above):
```hcl
mount_clients_dpdk = false
```

## NFS Protocol Gateways
We support creating NFS protocol gateways that will be mounted automatically to the cluster.
<br>In order to create you need to provide the number of protocol gateways instances you want (by default the number is 0),
for example:
```hcl
protocol_gateways_number = 2
```
This will automatically create 2 instances.
<br>In addition you can provide these optional variables:
```hcl
protocol                               = VALUE
protocol_gateway_secondary_ips_per_nic = 3
protocol_gateway_instance_type         = "c2-standard-8"
protocol_gateway_nics_num              = 2
protocol_gateway_disk_size             = 375
protocol_gateway_frontend_num          = 1
nfs_setup_protocol                     = false
```

<br>In order to create stateless clients, you need to set this variable:
```hcl
nfs_setup_protocol = true
```

## SMB Protocol Gateways
We support creating SMB protocol gateways that will be mounted automatically to the cluster.
<br>In order to create you need to provide the number of protocol gateways instances you want (by default the number is 0),

*The amount of SMB protocol gateways should be at least 3.*
</br>
for example:
```hcl
smb_protocol_gateways_number = 3
```
This will automatically create 3 instances.
<br>In addition you can provide these optional variables:
```hcl
smb_protocol_gateway_secondary_ips_per_nic = 3
smb_protocol_gateway_instance_type         = "c2-standard-8"
smb_protocol_gateway_nics_num              = 2
smb_protocol_gateway_disk_size             = 48
smb_protocol_gateway_frontend_cores_num    = 1
smb_setup_protocol                         = false
smb_cluster_name                           = ""
smb_domain_name                            = ""
smb_share_name                             = ""
```

<br>In order to create stateless clients, you need to set this variable:
```hcl
smb_setup_protocol = true
```

<br>In order to enable SMBW, you need to set this variable:
```hcl
smbw_enabled = true
```

To join an SMB cluster in Active Directory, you need to manually run this command:

`weka smb domain join <smb_domain_username> <smb_domain_password> [--server smb_server_name]`.


## Shared project
To enable using Shared VPC.
In order to setup, you must provide the following variables:
```hcl
shared_vpcs                    = [".."]
host_project                   = HOST_PROJECT_ID
host_shared_range              = [".."]
```

To enable project as host project, you must provide the following variable:
```hcl
enable_shared_vpc_host_project = true
```

To enable vpc network peering between host project and service project, you must provide the following variable:
```hcl
set_shared_vpc_peering = true
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.3.1 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~>2.4.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~>4.38.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~>2.4.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~>3.5.1 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~>0.9.1 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~>4.0.4 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | ~>2.4.0 |
| <a name="provider_google"></a> [google](#provider\_google) | ~>4.38.0 |
| <a name="provider_local"></a> [local](#provider\_local) | ~>2.4.0 |
| <a name="provider_random"></a> [random](#provider\_random) | ~>3.5.1 |
| <a name="provider_time"></a> [time](#provider\_time) | ~>0.9.1 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | ~>4.0.4 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_clients"></a> [clients](#module\_clients) | ./modules/clients | n/a |
| <a name="module_network"></a> [network](#module\_network) | ./modules/network | n/a |
| <a name="module_nfs_protocol_gateways"></a> [nfs\_protocol\_gateways](#module\_nfs\_protocol\_gateways) | ./modules/protocol_gateways | n/a |
| <a name="module_peering"></a> [peering](#module\_peering) | ./modules/vpc_peering | n/a |
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
| [google_project_iam_binding.cloudscheduler_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_binding) | resource |
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
| [google_secret_manager_secret_version.password_secret_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.token_secret_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.user_secret_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_storage_bucket.weka_deployment](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_object.cloud_functions_zip](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |
| [google_storage_bucket_object.state](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |
| [google_workflows_workflow.scale_down](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/workflows_workflow) | resource |
| [google_workflows_workflow.scale_up](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/workflows_workflow) | resource |
| [local_file.private_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.public_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [random_password.password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [time_sleep.wait_120_seconds](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [tls_private_key.ssh_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [archive_file.function_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [google_compute_network.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_compute_subnetwork.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_project.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_ssh_cidrs"></a> [allow\_ssh\_cidrs](#input\_allow\_ssh\_cidrs) | Allow port 22, if not provided, i.e leaving the default empty list, the rule will not be included in the SG | `list(string)` | `[]` | no |
| <a name="input_allow_weka_api_cidrs"></a> [allow\_weka\_api\_cidrs](#input\_allow\_weka\_api\_cidrs) | allow connection to port 14000 on weka backends and LB(if exists and not provided with dedicated SG)  from specified CIDRs, by default no CIDRs are allowed. All ports (including 14000) are allowed within VPC | `list(string)` | `[]` | no |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Determines whether to assign public IP to all instances deployed by TF module. Includes backends, clients and protocol gateways. | `bool` | `true` | no |
| <a name="input_client_frontend_cores"></a> [client\_frontend\_cores](#input\_client\_frontend\_cores) | Number of frontend cores to use on client instances, this number will reflect on number of NICs attached to instance, as each weka core requires dedicated NIC | `number` | `1` | no |
| <a name="input_client_instance_type"></a> [client\_instance\_type](#input\_client\_instance\_type) | The client virtual machine type (sku) to deploy. | `string` | `"c2-standard-8"` | no |
| <a name="input_client_source_image_id"></a> [client\_source\_image\_id](#input\_client\_source\_image\_id) | Client Source image ID to use, by default centos-7 is used, other distributive might work, but only centos-7 is tested by Weka with this TF module | `string` | `"projects/centos-cloud/global/images/centos-7-v20220719"` | no |
| <a name="input_clients_number"></a> [clients\_number](#input\_clients\_number) | The number of client virtual machines to deploy. | `number` | `0` | no |
| <a name="input_clients_use_dpdk"></a> [clients\_use\_dpdk](#input\_clients\_use\_dpdk) | Mount weka clients in DPDK mode | `bool` | `true` | no |
| <a name="input_cloud_functions_region_map"></a> [cloud\_functions\_region\_map](#input\_cloud\_functions\_region\_map) | Map of region to use for cloud functions, as some regions do not have cloud functions enabled | `map(string)` | <pre>{<br>  "asia-south2": "asia-south1",<br>  "europe-north1": "europe-west1",<br>  "europe-west4": "europe-west1",<br>  "southamerica-west1": "northamerica-northeast1",<br>  "us-east5": "us-east1"<br>}</pre> | no |
| <a name="input_cloud_run_dns_zone_name"></a> [cloud\_run\_dns\_zone\_name](#input\_cloud\_run\_dns\_zone\_name) | Name of existing Private dns zone for domain run.app. | `string` | `""` | no |
| <a name="input_cloud_scheduler_region_map"></a> [cloud\_scheduler\_region\_map](#input\_cloud\_scheduler\_region\_map) | Map of region to use for workflows scheduler, as some regions do not have scheduler enabled | `map(string)` | <pre>{<br>  "asia-south2": "asia-south1",<br>  "europe-north1": "europe-west1",<br>  "europe-west4": "europe-west1",<br>  "southamerica-west1": "northamerica-northeast1",<br>  "us-east5": "us-east1"<br>}</pre> | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster prefix for all resources | `string` | n/a | yes |
| <a name="input_cluster_size"></a> [cluster\_size](#input\_cluster\_size) | Weka cluster size | `number` | n/a | yes |
| <a name="input_containers_config_map"></a> [containers\_config\_map](#input\_containers\_config\_map) | Maps the number of objects and memory size per machine type. | <pre>map(object({<br>    compute  = number<br>    drive    = number<br>    frontend = number<br>    nics     = number<br>    memory   = list(string)<br>  }))</pre> | <pre>{<br>  "c2-standard-16": {<br>    "compute": 4,<br>    "drive": 1,<br>    "frontend": 1,<br>    "memory": [<br>      "24.2GB",<br>      "23.2GB"<br>    ],<br>    "nics": 7<br>  },<br>  "c2-standard-8": {<br>    "compute": 1,<br>    "drive": 1,<br>    "frontend": 1,<br>    "memory": [<br>      "4.2GB",<br>      "4GB"<br>    ],<br>    "nics": 4<br>  }<br>}</pre> | no |
| <a name="input_create_cloudscheduler_sa"></a> [create\_cloudscheduler\_sa](#input\_create\_cloudscheduler\_sa) | Create GCP cloudscheduler sa | `bool` | `true` | no |
| <a name="input_create_worker_pool"></a> [create\_worker\_pool](#input\_create\_worker\_pool) | Create worker pool | `bool` | `false` | no |
| <a name="input_default_disk_name"></a> [default\_disk\_name](#input\_default\_disk\_name) | The default disk name. | `string` | `"wekaio-volume"` | no |
| <a name="input_default_disk_size"></a> [default\_disk\_size](#input\_default\_disk\_size) | The default disk size. | `number` | `48` | no |
| <a name="input_enable_shared_vpc_host_project"></a> [enable\_shared\_vpc\_host\_project](#input\_enable\_shared\_vpc\_host\_project) | If this project is a shared VPC host project. If true, you must *not* set shared\_vpc variable. Default is false. | `bool` | `true` | no |
| <a name="input_endpoint_apis_internal_ip_address"></a> [endpoint\_apis\_internal\_ip\_address](#input\_endpoint\_apis\_internal\_ip\_address) | Private ip for all-apis endpoint | `string` | `"10.0.1.5"` | no |
| <a name="input_endpoint_vpcsc_internal_ip_address"></a> [endpoint\_vpcsc\_internal\_ip\_address](#input\_endpoint\_vpcsc\_internal\_ip\_address) | Private ip for vpc service connection endpoint | `string` | `"10.0.1.6"` | no |
| <a name="input_get_weka_io_token"></a> [get\_weka\_io\_token](#input\_get\_weka\_io\_token) | Get get.weka.io token for downloading weka | `string` | `""` | no |
| <a name="input_googleapis_dns_zone_name"></a> [googleapis\_dns\_zone\_name](#input\_googleapis\_dns\_zone\_name) | Name of existing Private dns zone for domain googleapis.com. | `string` | `""` | no |
| <a name="input_host_project"></a> [host\_project](#input\_host\_project) | The ID of the project that will serve as a Shared VPC host project | `string` | `""` | no |
| <a name="input_host_shared_range"></a> [host\_shared\_range](#input\_host\_shared\_range) | List of host range to allow sg | `list(string)` | `[]` | no |
| <a name="input_hotspare"></a> [hotspare](#input\_hotspare) | Hot-spare value. | `number` | `1` | no |
| <a name="input_install_weka_url"></a> [install\_weka\_url](#input\_install\_weka\_url) | Path to weka installation tar object | `string` | `""` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | Weka cluster backends machines type | `string` | `"c2-standard-8"` | no |
| <a name="input_mtu_size"></a> [mtu\_size](#input\_mtu\_size) | mtu size | `number` | `1460` | no |
| <a name="input_network_project_id"></a> [network\_project\_id](#input\_network\_project\_id) | Network project id | `string` | `""` | no |
| <a name="input_nfs_protocol_gateway_disk_size"></a> [nfs\_protocol\_gateway\_disk\_size](#input\_nfs\_protocol\_gateway\_disk\_size) | The protocol gateways' default disk size. | `number` | `375` | no |
| <a name="input_nfs_protocol_gateway_fe_cores_num"></a> [nfs\_protocol\_gateway\_fe\_cores\_num](#input\_nfs\_protocol\_gateway\_fe\_cores\_num) | The number of frontend cores on single protocol gateway machine. | `number` | `1` | no |
| <a name="input_nfs_protocol_gateway_machine_type"></a> [nfs\_protocol\_gateway\_machine\_type](#input\_nfs\_protocol\_gateway\_machine\_type) | The protocol gateways' virtual machine type (sku) to deploy. | `string` | `"c2-standard-8"` | no |
| <a name="input_nfs_protocol_gateway_secondary_ips_per_nic"></a> [nfs\_protocol\_gateway\_secondary\_ips\_per\_nic](#input\_nfs\_protocol\_gateway\_secondary\_ips\_per\_nic) | Number of secondary IPs per single NIC per protocol gateway virtual machine. | `number` | `3` | no |
| <a name="input_nfs_protocol_gateways_number"></a> [nfs\_protocol\_gateways\_number](#input\_nfs\_protocol\_gateways\_number) | The number of protocol gateway virtual machines to deploy. | `number` | `0` | no |
| <a name="input_nfs_setup_protocol"></a> [nfs\_setup\_protocol](#input\_nfs\_setup\_protocol) | Config protocol, default if false | `bool` | `false` | no |
| <a name="input_nics_numbers"></a> [nics\_numbers](#input\_nics\_numbers) | Number of nics per host | `number` | `-1` | no |
| <a name="input_nvmes_number"></a> [nvmes\_number](#input\_nvmes\_number) | Number of local nvmes per host | `number` | `2` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix for all resources | `string` | `"weka"` | no |
| <a name="input_private_dns_name"></a> [private\_dns\_name](#input\_private\_dns\_name) | Private dns name | `string` | `""` | no |
| <a name="input_private_zone_name"></a> [private\_zone\_name](#input\_private\_zone\_name) | Private zone name | `string` | `""` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id | `string` | n/a | yes |
| <a name="input_protection_level"></a> [protection\_level](#input\_protection\_level) | Cluster data protection level. | `number` | `2` | no |
| <a name="input_proxy_url"></a> [proxy\_url](#input\_proxy\_url) | Weka home proxy url | `string` | `""` | no |
| <a name="input_psc_subnet_cidr"></a> [psc\_subnet\_cidr](#input\_psc\_subnet\_cidr) | Cidr range for private service connection subnet | `string` | `"10.9.0.0/28"` | no |
| <a name="input_region"></a> [region](#input\_region) | Region name | `string` | n/a | yes |
| <a name="input_sa_email"></a> [sa\_email](#input\_sa\_email) | Service account email | `string` | `""` | no |
| <a name="input_set_dedicated_fe_container"></a> [set\_dedicated\_fe\_container](#input\_set\_dedicated\_fe\_container) | Create cluster with FE containers | `bool` | `true` | no |
| <a name="input_set_peering"></a> [set\_peering](#input\_set\_peering) | apply peering connection between subnets and subnets | `bool` | `true` | no |
| <a name="input_set_shared_vpc_peering"></a> [set\_shared\_vpc\_peering](#input\_set\_shared\_vpc\_peering) | Enable peering for shared vpc | `bool` | `true` | no |
| <a name="input_shared_vpcs"></a> [shared\_vpcs](#input\_shared\_vpcs) | list of shared vpc name | `list(string)` | `[]` | no |
| <a name="input_smb_cluster_name"></a> [smb\_cluster\_name](#input\_smb\_cluster\_name) | The name of the SMB setup. | `string` | `"Weka-SMB"` | no |
| <a name="input_smb_domain_name"></a> [smb\_domain\_name](#input\_smb\_domain\_name) | The domain to join the SMB cluster to. | `string` | `""` | no |
| <a name="input_smb_protocol_gateway_disk_size"></a> [smb\_protocol\_gateway\_disk\_size](#input\_smb\_protocol\_gateway\_disk\_size) | The protocol gateways' default disk size. | `number` | `375` | no |
| <a name="input_smb_protocol_gateway_fe_cores_num"></a> [smb\_protocol\_gateway\_fe\_cores\_num](#input\_smb\_protocol\_gateway\_fe\_cores\_num) | The number of frontend cores on single protocol gateway machine. | `number` | `1` | no |
| <a name="input_smb_protocol_gateway_machine_type"></a> [smb\_protocol\_gateway\_machine\_type](#input\_smb\_protocol\_gateway\_machine\_type) | The protocol gateways' virtual machine type (sku) to deploy. | `string` | `"c2-standard-8"` | no |
| <a name="input_smb_protocol_gateway_secondary_ips_per_nic"></a> [smb\_protocol\_gateway\_secondary\_ips\_per\_nic](#input\_smb\_protocol\_gateway\_secondary\_ips\_per\_nic) | Number of secondary IPs per single NIC per protocol gateway virtual machine. | `number` | `3` | no |
| <a name="input_smb_protocol_gateways_number"></a> [smb\_protocol\_gateways\_number](#input\_smb\_protocol\_gateways\_number) | The number of protocol gateway virtual machines to deploy. | `number` | `0` | no |
| <a name="input_smb_setup_protocol"></a> [smb\_setup\_protocol](#input\_smb\_setup\_protocol) | Config protocol, default if false | `bool` | `false` | no |
| <a name="input_smb_share_name"></a> [smb\_share\_name](#input\_smb\_share\_name) | The name of the SMB share | `string` | `"default"` | no |
| <a name="input_smbw_enabled"></a> [smbw\_enabled](#input\_smbw\_enabled) | Enable SMBW protocol. This option should be provided before cluster is created to leave extra capacity for SMBW setup. | `bool` | `true` | no |
| <a name="input_source_image_id"></a> [source\_image\_id](#input\_source\_image\_id) | Source image ID to use, by default centos-7 is used, other distributions might work, but only centos-7 is tested by Weka with this TF module | `string` | `"projects/centos-cloud/global/images/centos-7-v20220719"` | no |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | Ssh public key to pass to vms. | `string` | `null` | no |
| <a name="input_state_bucket_name"></a> [state\_bucket\_name](#input\_state\_bucket\_name) | Name of bucket state, cloud storage | `string` | `""` | no |
| <a name="input_stripe_width"></a> [stripe\_width](#input\_stripe\_width) | Stripe width = cluster\_size - protection\_level - 1 (by default). | `number` | `-1` | no |
| <a name="input_subnet_autocreate_as_private"></a> [subnet\_autocreate\_as\_private](#input\_subnet\_autocreate\_as\_private) | Create private subnet using nat gateway to route traffic. The default is public network. Relevant only when subnet\_ids is empty. | `bool` | `false` | no |
| <a name="input_subnets_name"></a> [subnets\_name](#input\_subnets\_name) | Subnets list name | `list(string)` | `[]` | no |
| <a name="input_subnets_range"></a> [subnets\_range](#input\_subnets\_range) | List of subnets to use for creating the cluster | `list(string)` | <pre>[<br>  "10.0.0.0/24",<br>  "10.1.0.0/24",<br>  "10.2.0.0/24",<br>  "10.3.0.0/24"<br>]</pre> | no |
| <a name="input_tiering_enable_obs_integration"></a> [tiering\_enable\_obs\_integration](#input\_tiering\_enable\_obs\_integration) | Determines whether to enable object stores integration with the Weka cluster. Set true to enable the integration. | `bool` | `false` | no |
| <a name="input_tiering_obs_name"></a> [tiering\_obs\_name](#input\_tiering\_obs\_name) | Name of OBS cloud storage | `string` | `""` | no |
| <a name="input_tiering_ssd_percent"></a> [tiering\_ssd\_percent](#input\_tiering\_ssd\_percent) | When OBS integration set to true , this parameter sets how much of the filesystem capacity should reside on SSD. For example, if this parameter is 20 and the total available SSD capacity is 20GB, the total capacity would be 100GB | `number` | `20` | no |
| <a name="input_traces_per_ionode"></a> [traces\_per\_ionode](#input\_traces\_per\_ionode) | The number of traces per ionode. Traces are low-level events generated by Weka processes and are used as troubleshooting information for support purposes. | `number` | `10` | no |
| <a name="input_vm_username"></a> [vm\_username](#input\_vm\_username) | Provided as part of output for automated use of terraform, in case of custom image and automated use of outputs replace this with user that should be used for ssh connection | `string` | `"weka"` | no |
| <a name="input_vpc_connector_id"></a> [vpc\_connector\_id](#input\_vpc\_connector\_id) | exiting vpc connector id to use for cloud functions, projects/<project-id>/locations/<region>/connectors/<connector-name> | `string` | `""` | no |
| <a name="input_vpc_connector_range"></a> [vpc\_connector\_range](#input\_vpc\_connector\_range) | list of connector to use for serverless vpc access | `string` | `"10.8.0.0/28"` | no |
| <a name="input_vpcs_name"></a> [vpcs\_name](#input\_vpcs\_name) | List of vpcs name | `list(string)` | `[]` | no |
| <a name="input_vpcs_range_to_peer_to_deployment_vpc"></a> [vpcs\_range\_to\_peer\_to\_deployment\_vpc](#input\_vpcs\_range\_to\_peer\_to\_deployment\_vpc) | list of vpcs range to peer | `list(string)` | `[]` | no |
| <a name="input_vpcs_to_peer_to_deployment_vpc"></a> [vpcs\_to\_peer\_to\_deployment\_vpc](#input\_vpcs\_to\_peer\_to\_deployment\_vpc) | list of vpcs name to peer | `list(string)` | `[]` | no |
| <a name="input_weka_home_url"></a> [weka\_home\_url](#input\_weka\_home\_url) | Weka Home url | `string` | `""` | no |
| <a name="input_weka_tar_bucket_name"></a> [weka\_tar\_bucket\_name](#input\_weka\_tar\_bucket\_name) | Name of weka tar bucket | `string` | `""` | no |
| <a name="input_weka_tar_project_id"></a> [weka\_tar\_project\_id](#input\_weka\_tar\_project\_id) | Project id of weka tar | `string` | `""` | no |
| <a name="input_weka_username"></a> [weka\_username](#input\_weka\_username) | Weka cluster username | `string` | `"admin"` | no |
| <a name="input_weka_version"></a> [weka\_version](#input\_weka\_version) | Weka version | `string` | `"4.2.6.90"` | no |
| <a name="input_worker_address_prefix_length"></a> [worker\_address\_prefix\_length](#input\_worker\_address\_prefix\_length) | Prefix length, such as 24 for /24 or 16 for /16. Must be 24 or lower. | `string` | `"16"` | no |
| <a name="input_worker_disk_size"></a> [worker\_disk\_size](#input\_worker\_disk\_size) | Size of the disk attached to the worker, in GB | `number` | `100` | no |
| <a name="input_worker_machine_type"></a> [worker\_machine\_type](#input\_worker\_machine\_type) | Machine type of a worker | `string` | `"e2-standard-4"` | no |
| <a name="input_worker_pool_address_cidr"></a> [worker\_pool\_address\_cidr](#input\_worker\_pool\_address\_cidr) | Choose an address range for the Cloud Build Private Pool workers. example: 10.37.0.0. Do not include a prefix length. | `string` | `"10.37.0.0"` | no |
| <a name="input_worker_pool_id"></a> [worker\_pool\_id](#input\_worker\_pool\_id) | Id of worker pool, Must be on the same project and region | `string` | `""` | no |
| <a name="input_workflow_map_region"></a> [workflow\_map\_region](#input\_workflow\_map\_region) | Map of region to use for workflow, as some regions do not have cloud workflow enabled | `map(string)` | <pre>{<br>  "southamerica-west1": "southamerica-east1"<br>}</pre> | no |
| <a name="input_yum_repo_server"></a> [yum\_repo\_server](#input\_yum\_repo\_server) | Yum repo server address | `string` | `""` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | Zone name | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
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
| <a name="output_smb_protocol_gateways_ips"></a> [smb\_protocol\_gateways\_ips](#output\_smb\_protocol\_gateways\_ips) | Ips of SMB protocol gateways |
| <a name="output_terminate_cluster_uri"></a> [terminate\_cluster\_uri](#output\_terminate\_cluster\_uri) | URL of terminate function |
| <a name="output_vm_username"></a> [vm\_username](#output\_vm\_username) | Provided as part of output for automated use of terraform, ssh user to weka cluster vm |
| <a name="output_weka_cluster_password_secret_id"></a> [weka\_cluster\_password\_secret\_id](#output\_weka\_cluster\_password\_secret\_id) | Secret id of weka\_password |
<!-- END_TF_DOCS -->
