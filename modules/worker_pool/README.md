# GCP shared vpc Terraform module
Terraform module that creates private pool for cloud functions build

## Usage
```hcl
module "create_worker_pool" {
  source              = "../../modules/worker_pool"
  project             = "myProject"
  region              = "europe-west1"
  vpcs                = ["weka-vpc-0", "weka-vpc-1", "weka-vpc-2", "weka-vpc-3"]
  cluster_name        = "myCluster"
  sa_email            = "weka-deploy-sa@myProject.iam.gserviceaccount.com"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.3.1 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >=6.21.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | >=6.21.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >=6.21.0 |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | >=6.21.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google-beta_google_project_service_identity.servicenetworking_agent](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_project_service_identity) | resource |
| [google_cloudbuild_worker_pool.pool](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudbuild_worker_pool) | resource |
| [google_compute_global_address.worker_range](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_network_peering_routes_config.service_networking_peering_config](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering_routes_config) | resource |
| [google_project_iam_member.service_networking_main_proj](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.service_networking_network_proj](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.servicenetworking_agent](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.servicenetworking](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_networking_connection.worker_pool_connection](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection) | resource |
| [google_compute_network.vnet](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_project.network_project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |
| [google_project.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster prefix for all resources | `string` | n/a | yes |
| <a name="input_network_project_id"></a> [network\_project\_id](#input\_network\_project\_id) | Network project id | `string` | `""` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix for all resources | `string` | `"weka"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region name | `string` | n/a | yes |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Vpc name | `string` | `""` | no |
| <a name="input_worker_address"></a> [worker\_address](#input\_worker\_address) | Choose an address range for the Cloud Build Private Pool workers. example: 10.37.0.0. Do not include a prefix length. | `string` | `"10.37.0.0"` | no |
| <a name="input_worker_address_prefix_length"></a> [worker\_address\_prefix\_length](#input\_worker\_address\_prefix\_length) | Prefix length, such as 24 for /24 or 16 for /16. Must be 24 or lower. | `string` | `"16"` | no |
| <a name="input_worker_disk_size"></a> [worker\_disk\_size](#input\_worker\_disk\_size) | Size of the disk attached to the worker, in GB | `number` | n/a | yes |
| <a name="input_worker_machine_type"></a> [worker\_machine\_type](#input\_worker\_machine\_type) | Machine type of a worker | `string` | n/a | yes |
| <a name="input_worker_pool_id"></a> [worker\_pool\_id](#input\_worker\_pool\_id) | Exiting worker pool id | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_worker_pool_id"></a> [worker\_pool\_id](#output\_worker\_pool\_id) | Worker pool id |
<!-- END_TF_DOCS -->
