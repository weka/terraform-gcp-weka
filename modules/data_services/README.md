<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.3.1 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >=6.21.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >=6.21.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_compute_instance_from_template.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_from_template) | resource |
| [google_compute_instance_template.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template) | resource |
| [google_compute_subnetwork.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Determines whether to assign public ip. | `bool` | n/a | yes |
| <a name="input_data_services_name"></a> [data\_services\_name](#input\_data\_services\_name) | The data services name. | `string` | n/a | yes |
| <a name="input_data_services_number"></a> [data\_services\_number](#input\_data\_services\_number) | The number of virtual machines to deploy as data services. | `number` | n/a | yes |
| <a name="input_deploy_function_url"></a> [deploy\_function\_url](#input\_deploy\_function\_url) | The URL of deploy function from cloud functions. | `string` | n/a | yes |
| <a name="input_labels_map"></a> [labels\_map](#input\_labels\_map) | A map of labels to assign the same metadata to all resources in the environment. Format: key:value. | `map(string)` | `{}` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | The virtual machine type (sku) to deploy | `string` | `"n2-standard-4"` | no |
| <a name="input_network_project_id"></a> [network\_project\_id](#input\_network\_project\_id) | Network project id | `string` | `""` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id | `string` | n/a | yes |
| <a name="input_proxy_url"></a> [proxy\_url](#input\_proxy\_url) | Weka home proxy url | `string` | `""` | no |
| <a name="input_region"></a> [region](#input\_region) | Region name | `string` | n/a | yes |
| <a name="input_report_function_url"></a> [report\_function\_url](#input\_report\_function\_url) | The URL of report function from cloud functions. | `string` | n/a | yes |
| <a name="input_root_volume_size"></a> [root\_volume\_size](#input\_root\_volume\_size) | The root volume size in GB. | `number` | `null` | no |
| <a name="input_sa_email"></a> [sa\_email](#input\_sa\_email) | service account email | `string` | n/a | yes |
| <a name="input_source_image_id"></a> [source\_image\_id](#input\_source\_image\_id) | Source image id | `string` | n/a | yes |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | Ssh public key to pass to vms. | `string` | n/a | yes |
| <a name="input_subnets_list"></a> [subnets\_list](#input\_subnets\_list) | list of subnet names | `list(string)` | n/a | yes |
| <a name="input_vm_username"></a> [vm\_username](#input\_vm\_username) | The user name for logging in to the virtual machines. | `string` | `"weka"` | no |
| <a name="input_weka_volume_size"></a> [weka\_volume\_size](#input\_weka\_volume\_size) | The disk size. | `number` | n/a | yes |
| <a name="input_yum_repository_appstream_url"></a> [yum\_repository\_appstream\_url](#input\_yum\_repository\_appstream\_url) | URL of the AppStream repository for appstream. Leave blank to use the default repositories. | `string` | `""` | no |
| <a name="input_yum_repository_baseos_url"></a> [yum\_repository\_baseos\_url](#input\_yum\_repository\_baseos\_url) | URL of the AppStream repository for baseos. Leave blank to use the default repositories. | `string` | `""` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | Zone name | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_data_services_name"></a> [data\_services\_name](#output\_data\_services\_name) | Data services name |
<!-- END_TF_DOCS -->
