<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.3.1 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~>4.38.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_create_service_account"></a> [create\_service\_account](#module\_create\_service\_account) | ../../modules/service_account | n/a |
| <a name="module_deploy_weka"></a> [deploy\_weka](#module\_deploy\_weka) | ../.. | n/a |
| <a name="module_setup_network"></a> [setup\_network](#module\_setup\_network) | ../../modules/setup_network | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | cluster name | `string` | n/a | yes |
| <a name="input_cluster_size"></a> [cluster\_size](#input\_cluster\_size) | weka cluster size | `number` | n/a | yes |
| <a name="input_get_weka_io_token"></a> [get\_weka\_io\_token](#input\_get\_weka\_io\_token) | get.weka.io token for downloading weka | `string` | n/a | yes |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | weka cluster backends machines type | `string` | n/a | yes |
| <a name="input_nics_number"></a> [nics\_number](#input\_nics\_number) | number of nics per host | `number` | n/a | yes |
| <a name="input_nvmes_number"></a> [nvmes\_number](#input\_nvmes\_number) | number of local nvmes per host | `number` | n/a | yes |
| <a name="input_path_to_modules"></a> [path\_to\_modules](#input\_path\_to\_modules) | path to modules, relative to actual project location or absolute | `string` | `"../.."` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | prefix for all resources | `string` | n/a | yes |
| <a name="input_private_network"></a> [private\_network](#input\_private\_network) | deploy weka in private network | `bool` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | project id | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | region name | `string` | n/a | yes |
| <a name="input_sa_name"></a> [sa\_name](#input\_sa\_name) | service account name | `string` | n/a | yes |
| <a name="input_sg_public_ssh_cidr_range"></a> [sg\_public\_ssh\_cidr\_range](#input\_sg\_public\_ssh\_cidr\_range) | list of ranges to allow ssh on public deployment | `list(string)` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Details of existing subnets, the key is contain subnet name | `list(string)` | `[]` | no |
| <a name="input_vpc_connector_name"></a> [vpc\_connector\_name](#input\_vpc\_connector\_name) | name of existing vpc connector | `string` | `""` | no |
| <a name="input_vpc_connector_range"></a> [vpc\_connector\_range](#input\_vpc\_connector\_range) | list of connector to use for serverless vpc access | `string` | n/a | yes |
| <a name="input_vpcs"></a> [vpcs](#input\_vpcs) | List of vpcs name | `list(string)` | `[]` | no |
| <a name="input_weka_username"></a> [weka\_username](#input\_weka\_username) | weka cluster username | `string` | `"admin"` | no |
| <a name="input_weka_version"></a> [weka\_version](#input\_weka\_version) | weka version | `string` | n/a | yes |
| <a name="input_zone"></a> [zone](#input\_zone) | zone name | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_helpers_commands"></a> [cluster\_helpers\_commands](#output\_cluster\_helpers\_commands) | n/a |
<!-- END_TF_DOCS -->