
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
| [google_compute_firewall.sg_private](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.sg_private_egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_network_peering.host-peering](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering) | resource |
| [google_compute_network_peering.peering-service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering) | resource |
| [google_compute_shared_vpc_service_project.service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_shared_vpc_service_project) | resource |
| [google_project_iam_binding.iam-binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_binding) | resource |
| [google_compute_network.vpc_list_ids](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deploy_on_host_project"></a> [deploy\_on\_host\_project](#input\_deploy\_on\_host\_project) | n/a | `bool` | n/a | yes |
| <a name="input_host_project"></a> [host\_project](#input\_host\_project) | n/a | `string` | `"The ID of the project that will serve as a Shared VPC host project"` | no |
| <a name="input_host_shared_range"></a> [host\_shared\_range](#input\_host\_shared\_range) | list of host range to allow sg | `list(string)` | `[]` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | prefix for all resources | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | project name | `string` | n/a | yes |
| <a name="input_sa_email"></a> [sa\_email](#input\_sa\_email) | service account email | `string` | `""` | no |
| <a name="input_shared_vpcs"></a> [shared\_vpcs](#input\_shared\_vpcs) | list of shared vpc name | `list(string)` | n/a | yes |
| <a name="input_vpcs"></a> [vpcs](#input\_vpcs) | list of vpcs name | `list(string)` | n/a | yes |

## Outputs

No outputs.
