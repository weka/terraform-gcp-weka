# Private VPC with shared vpcs
This example creates service account for weka deployment,
<br>all the network resources needed for weka deployment, including vpcs, peering, etc.
<br>weka cluster without internet and peering to a vpc in different project.

## Usage
```hcl
$ terraform init
$ terraform plan
$ terraform apply
```

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
| <a name="module_shared_vpc_peering"></a> [shared\_vpc\_peering](#module\_shared\_vpc\_peering) | ../../modules/shared_vpcs | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | cluster prefix for all resources | `string` | n/a | yes |
| <a name="input_cluster_size"></a> [cluster\_size](#input\_cluster\_size) | Weka cluster size | `number` | n/a | yes |
| <a name="input_host_project"></a> [host\_project](#input\_host\_project) | n/a | `string` | `"The ID of the project that will serve as a Shared VPC host project"` | no |
| <a name="input_host_shared_range"></a> [host\_shared\_range](#input\_host\_shared\_range) | list of host range to allow sg | `list(string)` | n/a | yes |
| <a name="input_install_url"></a> [install\_url](#input\_install\_url) | Path to weka installation tar object | `string` | n/a | yes |
| <a name="input_nvmes_number"></a> [nvmes\_number](#input\_nvmes\_number) | Number of local nvmes per host | `number` | n/a | yes |
| <a name="input_private_network"></a> [private\_network](#input\_private\_network) | deploy weka in private network | `bool` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region name | `string` | n/a | yes |
| <a name="input_shared_vpcs"></a> [shared\_vpcs](#input\_shared\_vpcs) | List of shared vpc name | `list(string)` | n/a | yes |
| <a name="input_subnets_cidr_range"></a> [subnets\_cidr\_range](#input\_subnets\_cidr\_range) | List of subnets to use for creating the cluster, the number of subnets must be 'nics\_number' | `list(string)` | n/a | yes |
| <a name="input_vpc_connector_range"></a> [vpc\_connector\_range](#input\_vpc\_connector\_range) | list of connector to use for serverless vpc access | `string` | n/a | yes |
| <a name="input_yum_repo_server"></a> [yum\_repo\_server](#input\_yum\_repo\_server) | Yum repo server address | `string` | n/a | yes |
| <a name="input_zone"></a> [zone](#input\_zone) | Zone name | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_helpers_commands"></a> [cluster\_helpers\_commands](#output\_cluster\_helpers\_commands) | n/a |
<!-- END_TF_DOCS -->