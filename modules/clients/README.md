<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.3.1 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~>4.38.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | ~>4.38.0 |

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
| <a name="input_disk_size"></a> [disk\_size](#input\_disk\_size) | size of disk | `number` | n/a | yes |
| <a name="input_instance_config_overrides"></a> [instance\_config\_overrides](#input\_instance\_config\_overrides) | Maps the number of objects and memory size per machine type. | <pre>map(object({<br>    dpdk_base_memory_mb = optional(number, 0)<br>    host_maintenance    = optional(string, "MIGRATE")<br>  }))</pre> | <pre>{<br>  "a2-highgpu-1g": {<br>    "host_maintenance": "TERMINATE"<br>  },<br>  "a2-highgpu-2g": {<br>    "host_maintenance": "TERMINATE"<br>  },<br>  "a2-highgpu-4g": {<br>    "host_maintenance": "TERMINATE"<br>  },<br>  "a2-highgpu-8g": {<br>    "host_maintenance": "TERMINATE"<br>  },<br>  "a2-megagpu-16g": {<br>    "host_maintenance": "TERMINATE"<br>  },<br>  "c2d-standard-112": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "c2d-standard-32": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "c2d-standard-56": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "n2-standard-128": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "n2-standard-32": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "n2-standard-48": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "n2-standard-96": {<br>    "dpdk_base_memory_mb": 32<br>  }<br>}</pre> | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | weka cluster clients machines type | `string` | n/a | yes |
| <a name="input_mount_clients_dpdk"></a> [mount\_clients\_dpdk](#input\_mount\_clients\_dpdk) | Mount weka clients in DPDK mode | `bool` | `true` | no |
| <a name="input_nics_numbers"></a> [nics\_numbers](#input\_nics\_numbers) | Number of core per client | `number` | `1` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | project name | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | region name | `string` | n/a | yes |
| <a name="input_sa_email"></a> [sa\_email](#input\_sa\_email) | service account email | `string` | n/a | yes |
| <a name="input_source_image_id"></a> [source\_image\_id](#input\_source\_image\_id) | os of image | `string` | n/a | yes |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | Ssh public key to pass to vms. | `string` | n/a | yes |
| <a name="input_ssh_user"></a> [ssh\_user](#input\_ssh\_user) | The user name for logging in to the virtual machines. | `string` | `"weka"` | no |
| <a name="input_subnets_list"></a> [subnets\_list](#input\_subnets\_list) | list of subnet names | `list(string)` | n/a | yes |
| <a name="input_yum_repo_server"></a> [yum\_repo\_server](#input\_yum\_repo\_server) | yum repo server address | `string` | `""` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | zone name | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_client_ips"></a> [client\_ips](#output\_client\_ips) | n/a |
<!-- END_TF_DOCS -->
