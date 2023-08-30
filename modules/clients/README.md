<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_compute_disk.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_disk) | resource |
| [google_compute_instance.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_subnetwork.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Determines whether to assign public ip. | `bool` | `true` | no |
| <a name="input_backend_lb_ip"></a> [backend\_lb\_ip](#input\_backend\_lb\_ip) | The backend load balancer ip address. | `string` | n/a | yes |
| <a name="input_clients_name"></a> [clients\_name](#input\_clients\_name) | Prefix clients name. | `string` | n/a | yes |
| <a name="input_clients_number"></a> [clients\_number](#input\_clients\_number) | n/a | `string` | `"Number of clients"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | cluster prefix for all resources | `string` | n/a | yes |
| <a name="input_disk_size"></a> [disk\_size](#input\_disk\_size) | size of disk | `number` | n/a | yes |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | weka cluster backends machines type | `string` | n/a | yes |
| <a name="input_mount_clients_dpdk"></a> [mount\_clients\_dpdk](#input\_mount\_clients\_dpdk) | Mount weka clients in DPDK mode | `bool` | `true` | no |
| <a name="input_nics_numbers"></a> [nics\_numbers](#input\_nics\_numbers) | Number of core per client | `number` | `1` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | prefix for all resources | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | project name | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | region name | `string` | n/a | yes |
| <a name="input_sa_email"></a> [sa\_email](#input\_sa\_email) | service account email | `string` | n/a | yes |
| <a name="input_source_image"></a> [source\_image](#input\_source\_image) | os of image | `string` | n/a | yes |
| <a name="input_subnets_list"></a> [subnets\_list](#input\_subnets\_list) | list of subnet names | `list(string)` | n/a | yes |
| <a name="input_yum_repo_server"></a> [yum\_repo\_server](#input\_yum\_repo\_server) | yum repo server address | `string` | `""` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | zone name | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->