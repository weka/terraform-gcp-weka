# GCP network setup Terraform module
Terraform module which sets up all network resources needed for weka deployment: vpcs, subnets, peering, 
security groups, vpc connector, health checks and dns.

## Usage
```hcl
module "setup_network" {
  source                   = "../../modules/setup_network"
  project                  = "myProject"
  region                   = "europe-west1"
  subnets-cidr-range       = ["10.0.0.0/24", "10.1.0.0/24", "10.2.0.0/24", "10.3.0.0/24"]
  zone                     = "europe-west1-b"
  vpc_connector_range      = "10.8.0.0/28"
}
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
| <a name="provider_google"></a> [google](#provider\_google) | ~>4.38.0 |

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
| [google_dns_managed_zone.private-zone](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone) | resource |
| [google_project_service.project-compute](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.project-dns](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.project-gcp-api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.project-vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.service-cloud-api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_vpc_access_connector.connector](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/vpc_access_connector) | resource |
| [google_compute_network.vpc_list_ids](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_compute_subnetwork.subnets_list_ids](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_prefix"></a> [prefix](#input\_prefix) | prefix for all resources | `string` | `"weka"` | no |
| <a name="input_private_network"></a> [private\_network](#input\_private\_network) | deploy weka in private network | `bool` | `false` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | project id | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | region name | `string` | n/a | yes |
| <a name="input_set_peering"></a> [set\_peering](#input\_set\_peering) | apply peering connection between subnets and subnets | `bool` | `true` | no |
| <a name="input_sg_public_ssh_cidr_range"></a> [sg\_public\_ssh\_cidr\_range](#input\_sg\_public\_ssh\_cidr\_range) | list of ranges to allow ssh on public deployment | `list(string)` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | List of subnets name | `list(string)` | `[]` | no |
| <a name="input_subnets_cidr_range"></a> [subnets\_cidr\_range](#input\_subnets\_cidr\_range) | list of subnets to use for creating the cluster, the number of subnets must be 'vpcs\_number' | `list(string)` | `[]` | no |
| <a name="input_vpc_connector_name"></a> [vpc\_connector\_name](#input\_vpc\_connector\_name) | exiting vpc connector name to use for cloud functions | `string` | `""` | no |
| <a name="input_vpc_connector_range"></a> [vpc\_connector\_range](#input\_vpc\_connector\_range) | list of connector to use for serverless vpc access | `string` | `""` | no |
| <a name="input_vpc_connector_region_map"></a> [vpc\_connector\_region\_map](#input\_vpc\_connector\_region\_map) | Map of region to use for vpc connector, as some regions do not have cloud functions enabled, and vpc connector needs to be in the same region | `map(string)` | <pre>{<br>  "asia-south2": "asia-south1",<br>  "europe-north1": "europe-west1",<br>  "europe-west4": "europe-west1",<br>  "southamerica-west1": "northamerica-northeast1",<br>  "us-east5": "us-east1"<br>}</pre> | no |
| <a name="input_vpcs"></a> [vpcs](#input\_vpcs) | List of vpcs name | `list(string)` | `[]` | no |
| <a name="input_vpcs_number"></a> [vpcs\_number](#input\_vpcs\_number) | number of vpcs | `number` | `4` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | zone name | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_gateway_address"></a> [gateway\_address](#output\_gateway\_address) | List of vpcs gateway addresses |
| <a name="output_private_dns_name"></a> [private\_dns\_name](#output\_private\_dns\_name) | Private zone dns name |
| <a name="output_private_zone_name"></a> [private\_zone\_name](#output\_private\_zone\_name) | Private zone name |
| <a name="output_subnets_range"></a> [subnets\_range](#output\_subnets\_range) | List of vpcs subnets ranges |
| <a name="output_subnetwork_name"></a> [subnetwork\_name](#output\_subnetwork\_name) | List of vpcs subnets names |
| <a name="output_vpc_connector_name"></a> [vpc\_connector\_name](#output\_vpc\_connector\_name) | Vpc connector name |
| <a name="output_vpcs_names"></a> [vpcs\_names](#output\_vpcs\_names) | List of vpcs names |
<!-- END_TF_DOCS -->
