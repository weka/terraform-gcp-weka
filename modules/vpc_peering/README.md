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
| [google_compute_firewall.egress_sg](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.ingress_sg](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_network_peering.peering](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering) | resource |
| [google_compute_network.vpc_to_peering](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_compute_network.vpcs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_prefix"></a> [prefix](#input\_prefix) | prefix for all resources | `string` | `"weka"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | project id | `string` | n/a | yes |
| <a name="input_vpc_to_peer_project_id"></a> [vpc\_to\_peer\_project\_id](#input\_vpc\_to\_peer\_project\_id) | Shared vpc project id | `string` | n/a | yes |
| <a name="input_vpcs_name"></a> [vpcs\_name](#input\_vpcs\_name) | list of vpcs name | `list(string)` | n/a | yes |
| <a name="input_vpcs_range_to_peer_to_deployment_vpc"></a> [vpcs\_range\_to\_peer\_to\_deployment\_vpc](#input\_vpcs\_range\_to\_peer\_to\_deployment\_vpc) | list of vpcs range to peer | `list(string)` | n/a | yes |
| <a name="input_vpcs_to_peer_to_deployment_vpc"></a> [vpcs\_to\_peer\_to\_deployment\_vpc](#input\_vpcs\_to\_peer\_to\_deployment\_vpc) | list of vpcs name to peer | `list(string)` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
