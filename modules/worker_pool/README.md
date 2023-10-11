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
| <a name="requirement_google"></a> [google](#requirement\_google) | ~>4.38.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~>3.2.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | ~>4.38.0 |
| <a name="provider_null"></a> [null](#provider\_null) | ~>3.2.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_cloudbuild_worker_pool.worker_pool](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudbuild_worker_pool) | resource |
| [google_compute_global_address.worker_range_ip](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_network_peering.peering_vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering) | resource |
| [google_compute_network_peering.peering_worker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering) | resource |
| [google_project_iam_binding.servicenetworking_admin_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_binding) | resource |
| [google_project_iam_binding.servicenetworking_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_binding) | resource |
| [google_project_iam_binding.worker_pool_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_binding) | resource |
| [google_project_service.servicenetworking](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_networking_connection.worker_pool_conn](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection) | resource |
| [null_resource.wait_service_enable](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [google_compute_network.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_compute_network.worker_pool_network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster prefix for all resources | `string` | n/a | yes |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix for all resources | `string` | `"weka"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region name | `string` | n/a | yes |
| <a name="input_sa_email"></a> [sa\_email](#input\_sa\_email) | service account email | `string` | n/a | yes |
| <a name="input_set_worker_pool_network_peering"></a> [set\_worker\_pool\_network\_peering](#input\_set\_worker\_pool\_network\_peering) | Create peering between worker pool network and vpcs networks | `bool` | n/a | yes |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Vpc name | `string` | `""` | no |
| <a name="input_worker_disk_size"></a> [worker\_disk\_size](#input\_worker\_disk\_size) | Size of the disk attached to the worker, in GB | `number` | n/a | yes |
| <a name="input_worker_machine_type"></a> [worker\_machine\_type](#input\_worker\_machine\_type) | Machine type of a worker | `string` | n/a | yes |
| <a name="input_worker_pool_name"></a> [worker\_pool\_name](#input\_worker\_pool\_name) | Exiting worker pool name | `string` | `""` | no |
| <a name="input_worker_pool_network"></a> [worker\_pool\_network](#input\_worker\_pool\_network) | Network name of worker pool, Must be on the same project and region | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_worker_pool_name"></a> [worker\_pool\_name](#output\_worker\_pool\_name) | Worker pool name |
<!-- END_TF_DOCS -->
