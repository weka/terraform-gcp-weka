## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.2.4 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~>4.27.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | ~>4.27.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_compute_firewall.fw_hc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.fw_ilb_to_backends](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.sg_private](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.sg_public_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_network.vpc_network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_network_peering.peering](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering) | resource |
| [google_compute_subnetwork.subnetwork](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_project_service.project-compute](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.project-gcp-api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.project-vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.service-cloud-api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_vpc_access_connector.connector](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/vpc_access_connector) | resource |
| [google_compute_network.vpc_list_ids](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_compute_subnetwork.subnets_list_ids](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_vpc_connector"></a> [create\_vpc\_connector](#input\_create\_vpc\_connector) | n/a | `bool` | n/a | yes |
| <a name="input_nics_number"></a> [nics\_number](#input\_nics\_number) | number of nics per host | `number` | n/a | yes |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | prefix for all resources | `string` | n/a | yes |
| <a name="input_private_network"></a> [private\_network](#input\_private\_network) | deploy weka in private network | `bool` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | project name | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | region name | `string` | n/a | yes |
| <a name="input_set_peering"></a> [set\_peering](#input\_set\_peering) | apply peering connection between subnets and subnets | `bool` | n/a | yes |
| <a name="input_sg_public_ssh_cidr_range"></a> [sg\_public\_ssh\_cidr\_range](#input\_sg\_public\_ssh\_cidr\_range) | list of ranges to allow ssh on public deployment | `list(string)` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | List of subnets name | `list(string)` | `[]` | no |
| <a name="input_subnets-cidr-range"></a> [subnets-cidr-range](#input\_subnets-cidr-range) | list of subnets to use for creating the cluster, the number of subnets must be 'nics\_number' | `list(string)` | n/a | yes |
| <a name="input_vpc_connector_name"></a> [vpc\_connector\_name](#input\_vpc\_connector\_name) | n/a | `string` | `""` | no |
| <a name="input_vpc_connector_range"></a> [vpc\_connector\_range](#input\_vpc\_connector\_range) | list of connector to use for serverless vpc access | `string` | n/a | yes |
| <a name="input_vpcs"></a> [vpcs](#input\_vpcs) | List of vpcs name | `list(string)` | `[]` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | zone name | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_output-gateway-address"></a> [output-gateway-address](#output\_output-gateway-address) | n/a |
| <a name="output_output-subnets-range"></a> [output-subnets-range](#output\_output-subnets-range) | n/a |
| <a name="output_output-subnetwork-name"></a> [output-subnetwork-name](#output\_output-subnetwork-name) | n/a |
| <a name="output_output-vpc-connector-name"></a> [output-vpc-connector-name](#output\_output-vpc-connector-name) | n/a |
| <a name="output_output-vpcs-names"></a> [output-vpcs-names](#output\_output-vpcs-names) | n/a |
