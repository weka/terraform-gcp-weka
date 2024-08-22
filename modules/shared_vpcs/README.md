# GCP shared vpc Terraform module
Terraform module which sets up peering between vpcs on different projects

## Usage
```hcl
module "shared_vpc" {
  source              = "../../modules/shared_vpcs"
  project             = "myProject"
  host_project        = "myHostProject"
  shared_vpcs         = ["shared-vpc"]
  vpcs                = ["weka-vpc-0", "weka-vpc-1", "weka-vpc-2", "weka-vpc-3"]
  sa_email            = "weka-deploy-sa@myProject.iam.gserviceaccount.com"
  host_shared_range   = ["10.26.1.0/24"]
  providers = {
    google.shared-vpc = hostProvider
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.3.1 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >=4.38.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >=4.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_compute_firewall.sg_private](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.sg_private_egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_network_peering.host_peering](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering) | resource |
| [google_compute_network_peering.peering_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering) | resource |
| [google_compute_shared_vpc_host_project.shared_vpc_host](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_shared_vpc_host_project) | resource |
| [google_compute_shared_vpc_service_project.shared_vpc_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_shared_vpc_service_project) | resource |
| [google_compute_network.vpc_list_ids](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_shared_vpc_host_project"></a> [enable\_shared\_vpc\_host\_project](#input\_enable\_shared\_vpc\_host\_project) | If this project is a shared VPC host project. If true, you must *not* set shared\_vpc variable. Default is false. | `bool` | `false` | no |
| <a name="input_host_project"></a> [host\_project](#input\_host\_project) | The ID of the project that will serve as a Shared VPC host project | `string` | n/a | yes |
| <a name="input_host_shared_range"></a> [host\_shared\_range](#input\_host\_shared\_range) | list of host range to allow sg | `list(string)` | `[]` | no |
| <a name="input_peering_name"></a> [peering\_name](#input\_peering\_name) | Peering name. The name format will be <vpc1>-<peering\_name>-<vpc2> | `string` | `"peering"` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | prefix for all resources | `string` | `"weka"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | project id | `string` | n/a | yes |
| <a name="input_set_shared_vpc_peering"></a> [set\_shared\_vpc\_peering](#input\_set\_shared\_vpc\_peering) | n/a | `bool` | `false` | no |
| <a name="input_shared_vpc_project_id"></a> [shared\_vpc\_project\_id](#input\_shared\_vpc\_project\_id) | Shared vpc project id | `string` | n/a | yes |
| <a name="input_shared_vpcs"></a> [shared\_vpcs](#input\_shared\_vpcs) | list of shared vpc name | `list(string)` | n/a | yes |
| <a name="input_vpcs_name"></a> [vpcs\_name](#input\_vpcs\_name) | list of vpcs name | `list(string)` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
