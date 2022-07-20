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
| [google_compute_firewall.allow-bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow-http](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow-internal](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.egress-firewall-rules](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.sg_private](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_instance.vm-repo](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_network.vpc_network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_network_peering.peering-global](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering) | resource |
| [google_compute_network_peering.peering-vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering) | resource |
| [google_compute_subnetwork.private_subnet](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_compute_subnetwork.public_subnet](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_dns_managed_zone.private-zone](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone) | resource |
| [google_dns_record_set.record-a](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_project_service.project-dns](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_compute_image.centos_7](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_image) | data source |
| [google_compute_network.vpcs_ids](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_family_image"></a> [family\_image](#input\_family\_image) | The family name of the image | `string` | `"centos-7"` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | repo image type | `string` | `"c2-standard-4"` | no |
| <a name="input_private_cidr_range"></a> [private\_cidr\_range](#input\_private\_cidr\_range) | n/a | `string` | `"10.26.1.0/24"` | no |
| <a name="input_project"></a> [project](#input\_project) | project name | `string` | n/a | yes |
| <a name="input_project_image"></a> [project\_image](#input\_project\_image) | The project in which the resource belongs | `string` | `"centos-cloud"` | no |
| <a name="input_public_cidr_range"></a> [public\_cidr\_range](#input\_public\_cidr\_range) | n/a | `string` | `"10.26.2.0/24"` | no |
| <a name="input_region"></a> [region](#input\_region) | region name | `string` | n/a | yes |
| <a name="input_vpc_range"></a> [vpc\_range](#input\_vpc\_range) | n/a | `string` | `"10.0.0.0/24"` | no |
| <a name="input_vpcs_peering"></a> [vpcs\_peering](#input\_vpcs\_peering) | List of vpc to peering repo network | `list(string)` | n/a | yes |
| <a name="input_zone"></a> [zone](#input\_zone) | zone of centos repo local server | `string` | n/a | yes |

## Outputs

No outputs.
