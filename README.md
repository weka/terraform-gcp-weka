# GCP weka deployment Terraform module
Terraform module that creates weka deployments.
This module creates many resources as launch template, cloud functions, workflows, cloud scheduler etc.
<br>**Note**: when applying this module it will create workflow that will automatically start instances according to the
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

## OBS
We support tiering to bucket.
In order to setup tiering, you must supply the following variables:
```hcl
set_obs_integration = true
obs_name            = "..."
tiering_ssd_percent = 20
```

## Clients
We support creating clients that will be mounted automatically to the cluster.
<br>In order to create clients you need to provide the number of clients you want (by default the number is 0),
for example:
```hcl
clients_number = 2
```
This will automatically create 2 clients.
<br>In addition you can supply these optional variables:
```hcl
client_instance_type = "c2-standard-8"
client_nics_num = DESIRED_NUM
```
### Mounting clients in udp mode
In order to mount clients in udp mode you should pass the following param (in addition to the above):
```hcl
mount_clients_dpdk = false
```

## Protocol Gateways
We support creating protocol gateways that will be mounted automatically to the cluster.
<br>In order to create you need to provide the number of protocol gateways instances you want (by default the number is 0),
for example:
```hcl
protocol_gateways_number = 2
```
This will automatically create 2 instances.
<br>In addition you can supply these optional variables:
```hcl
protocol                               = VALUE
protocol_gateway_secondary_ips_per_nic = 3
protocol_gateway_instance_type         = "c2-standard-8"
protocol_gateway_nics_num              = 2
protocol_gateway_disk_size             = 375
protocol_gateway_frontend_num          = 1
```


## Shared project

```hcl
shared_vpcs        = [".."]
host_project       = HOST_PROJECT_ID
host_shared_range  = [".."]
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.3.1 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~>4.38.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | n/a |
| <a name="provider_google"></a> [google](#provider\_google) | ~>4.38.0 |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_clients"></a> [clients](#module\_clients) | ./modules/clients | n/a |

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
| [google_compute_instance_group.instance_group](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_group) | resource |
| [google_compute_instance_template.backends_template](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template) | resource |
| [google_compute_region_backend_service.backend_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service) | resource |
| [google_compute_region_backend_service.ui_backend_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service) | resource |
| [google_compute_region_health_check.health_check](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_health_check) | resource |
| [google_compute_region_health_check.ui_check](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_health_check) | resource |
| [google_dns_record_set.record-a](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_dns_record_set.ui-record-a](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_eventarc_trigger.scale_down_trigger](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/eventarc_trigger) | resource |
| [google_eventarc_trigger.scale_up_trigger](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/eventarc_trigger) | resource |
| [google_project_iam_binding.cloudscheduler-binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_binding) | resource |
| [google_project_service.artifactregistry-api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.cloud-build-api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.compute-api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.eventarc-api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.project-function-api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.run-api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.secret_manager](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.service-scheduler-api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.service-usage-api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
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
| [null_resource.terminate-cluster](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_password.password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [archive_file.function_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [google_compute_network.vpc_list_ids](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_compute_subnetwork.subnets_list_ids](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_project.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_add_frontend_containers"></a> [add\_frontend\_containers](#input\_add\_frontend\_containers) | Create cluster with FE containers | `bool` | `true` | no |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Determines whether to assign public ip. | `bool` | `true` | no |
| <a name="input_client_instance_type"></a> [client\_instance\_type](#input\_client\_instance\_type) | The client virtual machine type (sku) to deploy. | `string` | `"c2-standard-8"` | no |
| <a name="input_client_nics_num"></a> [client\_nics\_num](#input\_client\_nics\_num) | The client NICs number. | `string` | `2` | no |
| <a name="input_clients_number"></a> [clients\_number](#input\_clients\_number) | The number of client virtual machines to deploy. | `number` | `0` | no |
| <a name="input_cloud_functions_region_map"></a> [cloud\_functions\_region\_map](#input\_cloud\_functions\_region\_map) | Map of region to use for cloud functions, as some regions do not have cloud functions enabled | `map(string)` | <pre>{<br>  "asia-south2": "asia-south1",<br>  "europe-north1": "europe-west1",<br>  "europe-west4": "europe-west1",<br>  "southamerica-west1": "northamerica-northeast1",<br>  "us-east5": "us-east1"<br>}</pre> | no |
| <a name="input_cloud_scheduler_region_map"></a> [cloud\_scheduler\_region\_map](#input\_cloud\_scheduler\_region\_map) | Map of region to use for workflows scheduler, as some regions do not have scheduler enabled | `map(string)` | <pre>{<br>  "asia-south2": "asia-south1",<br>  "europe-north1": "europe-west1",<br>  "europe-west4": "europe-west1",<br>  "southamerica-west1": "northamerica-northeast1",<br>  "us-east5": "us-east1"<br>}</pre> | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster prefix for all resources | `string` | n/a | yes |
| <a name="input_cluster_size"></a> [cluster\_size](#input\_cluster\_size) | Weka cluster size | `number` | n/a | yes |
| <a name="input_container_number_map"></a> [container\_number\_map](#input\_container\_number\_map) | Maps the number of objects and memory size per machine type. | <pre>map(object({<br>    compute  = number<br>    drive    = number<br>    frontend = number<br>    nics     = number<br>    memory   = list(string)<br>  }))</pre> | <pre>{<br>  "c2-standard-16": {<br>    "compute": 4,<br>    "drive": 1,<br>    "frontend": 1,<br>    "memory": [<br>      "24.2GB",<br>      "23.2GB"<br>    ],<br>    "nics": 7<br>  },<br>  "c2-standard-8": {<br>    "compute": 1,<br>    "drive": 1,<br>    "frontend": 1,<br>    "memory": [<br>      "4.2GB",<br>      "4GB"<br>    ],<br>    "nics": 4<br>  }<br>}</pre> | no |
| <a name="input_create_cloudscheduler_sa"></a> [create\_cloudscheduler\_sa](#input\_create\_cloudscheduler\_sa) | Should or not crate gcp cloudscheduler sa | `bool` | `true` | no |
| <a name="input_default_disk_size"></a> [default\_disk\_size](#input\_default\_disk\_size) | The client' default disk size. | `number` | `48` | no |
| <a name="input_get_weka_io_token"></a> [get\_weka\_io\_token](#input\_get\_weka\_io\_token) | Get get.weka.io token for downloading weka | `string` | `""` | no |
| <a name="input_hotspare"></a> [hotspare](#input\_hotspare) | Hot-spare value. | `number` | `1` | no |
| <a name="input_install_url"></a> [install\_url](#input\_install\_url) | Path to weka installation tar object | `string` | `""` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | Weka cluster backends machines type | `string` | `"c2-standard-8"` | no |
| <a name="input_mount_clients_dpdk"></a> [mount\_clients\_dpdk](#input\_mount\_clients\_dpdk) | Mount weka clients in DPDK mode | `bool` | `true` | no |
| <a name="input_nics_number"></a> [nics\_number](#input\_nics\_number) | Number of nics per host | `number` | `-1` | no |
| <a name="input_nvmes_number"></a> [nvmes\_number](#input\_nvmes\_number) | Number of local nvmes per host | `number` | n/a | yes |
| <a name="input_obs_name"></a> [obs\_name](#input\_obs\_name) | Name of OBS cloud storage | `string` | `""` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix for all resources | `string` | `"weka"` | no |
| <a name="input_private_dns_name"></a> [private\_dns\_name](#input\_private\_dns\_name) | Private dns name | `string` | n/a | yes |
| <a name="input_private_dns_zone"></a> [private\_dns\_zone](#input\_private\_dns\_zone) | Name of private dns zone | `string` | n/a | yes |
| <a name="input_private_network"></a> [private\_network](#input\_private\_network) | Deploy weka in private network | `bool` | `false` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id | `string` | n/a | yes |
| <a name="input_protection_level"></a> [protection\_level](#input\_protection\_level) | Cluster data protection level. | `number` | `2` | no |
| <a name="input_region"></a> [region](#input\_region) | Region name | `string` | n/a | yes |
| <a name="input_sa_email"></a> [sa\_email](#input\_sa\_email) | Service account email | `string` | n/a | yes |
| <a name="input_set_obs_integration"></a> [set\_obs\_integration](#input\_set\_obs\_integration) | Determines whether to enable object stores integration with the Weka cluster. Set true to enable the integration. | `bool` | `false` | no |
| <a name="input_state_bucket_name"></a> [state\_bucket\_name](#input\_state\_bucket\_name) | Name of bucket state, cloud storage | `string` | `""` | no |
| <a name="input_stripe_width"></a> [stripe\_width](#input\_stripe\_width) | Stripe width = cluster\_size - protection\_level - 1 (by default). | `number` | `-1` | no |
| <a name="input_subnets_name"></a> [subnets\_name](#input\_subnets\_name) | Subnets list name | `list(string)` | n/a | yes |
| <a name="input_tiering_ssd_percent"></a> [tiering\_ssd\_percent](#input\_tiering\_ssd\_percent) | When OBS integration set to true , this parameter sets how much of the filesystem capacity should reside on SSD. For example, if this parameter is 20 and the total available SSD capacity is 20GB, the total capacity would be 100GB | `number` | `20` | no |
| <a name="input_traces_per_ionode"></a> [traces\_per\_ionode](#input\_traces\_per\_ionode) | The number of traces per ionode. Traces are low-level events generated by Weka processes and are used as troubleshooting information for support purposes. | `number` | `10` | no |
| <a name="input_vpc_connector"></a> [vpc\_connector](#input\_vpc\_connector) | Connector name to use for serverless vpc access | `string` | n/a | yes |
| <a name="input_vpcs"></a> [vpcs](#input\_vpcs) | List of vpcs name | `list(string)` | n/a | yes |
| <a name="input_weka_image_id"></a> [weka\_image\_id](#input\_weka\_image\_id) | Weka image id | `string` | `"projects/centos-cloud/global/images/centos-7-v20220719"` | no |
| <a name="input_weka_username"></a> [weka\_username](#input\_weka\_username) | Weka cluster username | `string` | `"admin"` | no |
| <a name="input_weka_version"></a> [weka\_version](#input\_weka\_version) | Weka version | `string` | `"4.2.1"` | no |
| <a name="input_worker_pool_name"></a> [worker\_pool\_name](#input\_worker\_pool\_name) | Name of worker pool, Must be on the same project and region | `string` | `""` | no |
| <a name="input_workflow_map_region"></a> [workflow\_map\_region](#input\_workflow\_map\_region) | Map of region to use for workflow, as some regions do not have cloud workflow enabled | `map(string)` | <pre>{<br>  "southamerica-west1": "southamerica-east1"<br>}</pre> | no |
| <a name="input_yum_repo_server"></a> [yum\_repo\_server](#input\_yum\_repo\_server) | Yum repo server address | `string` | `""` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | Zone name | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_client_ips"></a> [client\_ips](#output\_client\_ips) | If 'private\_network' is set to false, it will output clients public ips, otherwise private ips. |
| <a name="output_cluster_helper_commands"></a> [cluster\_helper\_commands](#output\_cluster\_helper\_commands) | Useful commands and script to interact with weka cluster |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_get_cluster_status_uri"></a> [get\_cluster\_status\_uri](#output\_get\_cluster\_status\_uri) | n/a |
| <a name="output_lb_url"></a> [lb\_url](#output\_lb\_url) | n/a |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | n/a |
| <a name="output_resize_cluster_uri"></a> [resize\_cluster\_uri](#output\_resize\_cluster\_uri) | n/a |
| <a name="output_ssh_user"></a> [ssh\_user](#output\_ssh\_user) | ssh user for weka cluster |
| <a name="output_terminate_cluster_uri"></a> [terminate\_cluster\_uri](#output\_terminate\_cluster\_uri) | n/a |
| <a name="output_weka_cluster_password_secret_id"></a> [weka\_cluster\_password\_secret\_id](#output\_weka\_cluster\_password\_secret\_id) | n/a |
<!-- END_TF_DOCS -->
