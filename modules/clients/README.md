<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.3.1 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >=6.12.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >=6.12.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_compute_instance.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_subnetwork.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Determines whether to assign public ip. | `bool` | `true` | no |
| <a name="input_backend_lb_ip"></a> [backend\_lb\_ip](#input\_backend\_lb\_ip) | The backend load balancer ip address. | `string` | n/a | yes |
| <a name="input_clients_name"></a> [clients\_name](#input\_clients\_name) | Prefix clients name. | `string` | n/a | yes |
| <a name="input_clients_number"></a> [clients\_number](#input\_clients\_number) | n/a | `string` | `"Number of clients"` | no |
| <a name="input_clients_use_dpdk"></a> [clients\_use\_dpdk](#input\_clients\_use\_dpdk) | Mount weka clients in DPDK mode | `bool` | `true` | no |
| <a name="input_custom_data"></a> [custom\_data](#input\_custom\_data) | Custom data to pass to the instances | `string` | `""` | no |
| <a name="input_frontend_container_cores_num"></a> [frontend\_container\_cores\_num](#input\_frontend\_container\_cores\_num) | Number of frontend cores to use on client instances, this number will reflect on number of NICs attached to instance, as each weka core requires dedicated NIC | `number` | `1` | no |
| <a name="input_instance_config_overrides"></a> [instance\_config\_overrides](#input\_instance\_config\_overrides) | Maps the number of objects and memory size per machine type. | <pre>map(object({<br>    dpdk_base_memory_mb = optional(number, 0)<br>    host_maintenance    = optional(string, "MIGRATE")<br>  }))</pre> | <pre>{<br>  "a2-highgpu-1g": {<br>    "host_maintenance": "TERMINATE"<br>  },<br>  "a2-highgpu-2g": {<br>    "dpdk_base_memory_mb": 32,<br>    "host_maintenance": "TERMINATE"<br>  },<br>  "a2-highgpu-4g": {<br>    "dpdk_base_memory_mb": 32,<br>    "host_maintenance": "TERMINATE"<br>  },<br>  "a2-highgpu-8g": {<br>    "dpdk_base_memory_mb": 32,<br>    "host_maintenance": "TERMINATE"<br>  },<br>  "a2-megagpu-16g": {<br>    "dpdk_base_memory_mb": 32,<br>    "host_maintenance": "TERMINATE"<br>  },<br>  "c2d-highmem-56": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "c2d-standard-112": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "c2d-standard-32": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "c2d-standard-56": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "n2-highmem-32": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "n2-standard-128": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "n2-standard-32": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "n2-standard-48": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "n2-standard-80": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "n2-standard-96": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "n2d-highmem-32": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "n2d-highmem-64": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "n2d-standard-32": {<br>    "dpdk_base_memory_mb": 32<br>  },<br>  "n2d-standard-64": {<br>    "dpdk_base_memory_mb": 32<br>  }<br>}</pre> | no |
| <a name="input_labels_map"></a> [labels\_map](#input\_labels\_map) | A map of labels to assign the same metadata to all resources in the environment. Format: key:value. | `map(string)` | `{}` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | weka cluster clients machines type | `string` | n/a | yes |
| <a name="input_network_project_id"></a> [network\_project\_id](#input\_network\_project\_id) | Network project id | `string` | `""` | no |
| <a name="input_nic_type"></a> [nic\_type](#input\_nic\_type) | The type of vNIC. Possible values: GVNIC, VIRTIO\_NET. | `string` | `null` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | project name | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | region name | `string` | n/a | yes |
| <a name="input_sa_email"></a> [sa\_email](#input\_sa\_email) | service account email | `string` | n/a | yes |
| <a name="input_source_image_id"></a> [source\_image\_id](#input\_source\_image\_id) | os of image | `string` | `"rocky-linux-8-v20240910"` | no |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | Ssh public key to pass to vms. | `string` | n/a | yes |
| <a name="input_subnets_list"></a> [subnets\_list](#input\_subnets\_list) | list of subnet names | `list(string)` | n/a | yes |
| <a name="input_vm_username"></a> [vm\_username](#input\_vm\_username) | The user name for logging in to the virtual machines. | `string` | `"weka"` | no |
| <a name="input_yum_repository_appstream_url"></a> [yum\_repository\_appstream\_url](#input\_yum\_repository\_appstream\_url) | URL of the AppStream repository for appstream. Leave blank to use the default repositories. | `string` | `""` | no |
| <a name="input_yum_repository_baseos_url"></a> [yum\_repository\_baseos\_url](#input\_yum\_repository\_baseos\_url) | URL of the AppStream repository for baseos. Leave blank to use the default repositories. | `string` | `""` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | zone name | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_client_ips"></a> [client\_ips](#output\_client\_ips) | n/a |
<!-- END_TF_DOCS -->
