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
| <a name="requirement_google"></a> [google](#requirement\_google) | >=6.12.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 3.83.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >=6.12.0 |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | ~> 3.83.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google-beta_google_vpc_access_connector.connector](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_vpc_access_connector) | resource |
| [google_compute_firewall.allow_endpoint_sg](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.fw_cloud_run](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.fw_hc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.fw_ilb_to_backends](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.fw_serverless_to_vpc_connector](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.fw_vpc_connector_health_checks](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.fw_vpc_connector_requests](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.fw_vpc_connector_to_serverless](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.sg_custom_ingress_rules](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.sg_private](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.sg_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.sg_weka_api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_global_address.apis_ip](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_global_address.vpcsc_ip](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_global_forwarding_rule.apis_forwarding_rule](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_global_forwarding_rule.vpcsc_forwarding_rule](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_network.vpc_network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_network_peering.peering](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering) | resource |
| [google_compute_route.private_googleapis_route](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route) | resource |
| [google_compute_route.restricted_googleapis_route](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route) | resource |
| [google_compute_router.router](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.connector_subnet](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_compute_subnetwork.psc_subnetwork](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_compute_subnetwork.subnetwork](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_dns_managed_zone.cloud_run_zone](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone) | resource |
| [google_dns_managed_zone.googleapis_zone](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone) | resource |
| [google_dns_managed_zone.private_zone](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone) | resource |
| [google_dns_record_set.apis_endpoint_record](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_dns_record_set.cloud_run_endpoint_record](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_project_iam_member.cloudservices_network_user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.vpcaccess_network_user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.project_compute](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.project_dns](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.project_gcp_api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.project_vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.psc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.service_cloud_api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_compute_network.vpc_list_ids](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_compute_subnetwork.subnets_list_ids](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_project.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_ssh_cidrs"></a> [allow\_ssh\_cidrs](#input\_allow\_ssh\_cidrs) | Allow port 22, if not provided, i.e leaving the default empty list, the rule will not be included in the SG | `list(string)` | `[]` | no |
| <a name="input_allow_weka_api_cidrs"></a> [allow\_weka\_api\_cidrs](#input\_allow\_weka\_api\_cidrs) | allow connection to port 14000 on weka backends and LB(if exists and not provided with dedicated SG)  from specified CIDRs, by default no CIDRs are allowed. All ports (including 14000) are allowed within VPC | `list(string)` | `[]` | no |
| <a name="input_cloud_run_dns_zone_name"></a> [cloud\_run\_dns\_zone\_name](#input\_cloud\_run\_dns\_zone\_name) | Name of existing Private dns zone for domain run.app. | `string` | `""` | no |
| <a name="input_create_nat_gateway"></a> [create\_nat\_gateway](#input\_create\_nat\_gateway) | NAT needs to be created when no public ip is assigned to the backend, to allow internet access | `bool` | `false` | no |
| <a name="input_endpoint_apis_internal_ip_address"></a> [endpoint\_apis\_internal\_ip\_address](#input\_endpoint\_apis\_internal\_ip\_address) | Private ip for all-apis endpoint | `string` | `"10.0.1.5"` | no |
| <a name="input_endpoint_vpcsc_internal_ip_address"></a> [endpoint\_vpcsc\_internal\_ip\_address](#input\_endpoint\_vpcsc\_internal\_ip\_address) | Private ip for vpc service connection endpoint | `string` | `"10.0.1.6"` | no |
| <a name="input_googleapis_dns_zone_name"></a> [googleapis\_dns\_zone\_name](#input\_googleapis\_dns\_zone\_name) | Name of existing Private dns zone for domain googleapis.com. | `string` | `""` | no |
| <a name="input_labels_map"></a> [labels\_map](#input\_labels\_map) | A map of labels to assign the same metadata to all resources in the environment. Format: key:value. | `map(string)` | `{}` | no |
| <a name="input_mtu_size"></a> [mtu\_size](#input\_mtu\_size) | mtu size | `number` | n/a | yes |
| <a name="input_network_project_id"></a> [network\_project\_id](#input\_network\_project\_id) | Network project id | `string` | `""` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | prefix for all resources | `string` | `"weka"` | no |
| <a name="input_private_dns_name"></a> [private\_dns\_name](#input\_private\_dns\_name) | Private dns name | `string` | `""` | no |
| <a name="input_private_zone_name"></a> [private\_zone\_name](#input\_private\_zone\_name) | Private zone name | `string` | `""` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | project id | `string` | n/a | yes |
| <a name="input_psc_subnet_cidr"></a> [psc\_subnet\_cidr](#input\_psc\_subnet\_cidr) | Cidr range for private service connection subnet | `string` | `"10.9.0.0/28"` | no |
| <a name="input_region"></a> [region](#input\_region) | region name | `string` | n/a | yes |
| <a name="input_set_peering"></a> [set\_peering](#input\_set\_peering) | apply peering connection between subnets and subnets | `bool` | `true` | no |
| <a name="input_sg_custom_ingress_rules"></a> [sg\_custom\_ingress\_rules](#input\_sg\_custom\_ingress\_rules) | Custom inbound rules to be added to the security group. | <pre>list(object({<br>    to_port     = number<br>    protocol    = string<br>    cidr_blocks = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_subnet_autocreate_as_private"></a> [subnet\_autocreate\_as\_private](#input\_subnet\_autocreate\_as\_private) | Create private subnet using nat gateway to route traffic. The default is public network. Relevant only when subnet\_ids is empty. | `bool` | `false` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | List of subnets name | `list(string)` | `[]` | no |
| <a name="input_subnets_range"></a> [subnets\_range](#input\_subnets\_range) | list of subnets to use for creating the cluster, the number of subnets must be 'vpcs\_number' | `list(string)` | `[]` | no |
| <a name="input_vpc_connector_id"></a> [vpc\_connector\_id](#input\_vpc\_connector\_id) | exiting vpc connector id to use for cloud functions | `string` | `""` | no |
| <a name="input_vpc_connector_range"></a> [vpc\_connector\_range](#input\_vpc\_connector\_range) | list of connector to use for serverless vpc access | `string` | `""` | no |
| <a name="input_vpc_connector_region_map"></a> [vpc\_connector\_region\_map](#input\_vpc\_connector\_region\_map) | Map of region to use for vpc connector, as some regions do not have cloud functions enabled, and vpc connector needs to be in the same region | `map(string)` | <pre>{<br>  "asia-south2": "asia-south1",<br>  "europe-north1": "europe-west1",<br>  "europe-west4": "europe-west1",<br>  "southamerica-west1": "northamerica-northeast1",<br>  "us-east5": "us-east1"<br>}</pre> | no |
| <a name="input_vpc_number"></a> [vpc\_number](#input\_vpc\_number) | Number of vpcs, should be passed only when not creating subnets. | `number` | `0` | no |
| <a name="input_vpcs"></a> [vpcs](#input\_vpcs) | List of vpcs name | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_gateway_address"></a> [gateway\_address](#output\_gateway\_address) | List of vpcs gateway addresses |
| <a name="output_private_dns_name"></a> [private\_dns\_name](#output\_private\_dns\_name) | Private zone dns name |
| <a name="output_private_zone_name"></a> [private\_zone\_name](#output\_private\_zone\_name) | Private zone name |
| <a name="output_subnets_range"></a> [subnets\_range](#output\_subnets\_range) | List of vpcs subnets ranges |
| <a name="output_subnetwork_name"></a> [subnetwork\_name](#output\_subnetwork\_name) | List of vpcs subnets names |
| <a name="output_vpc_connector_id"></a> [vpc\_connector\_id](#output\_vpc\_connector\_id) | Vpc connector id |
| <a name="output_vpc_self_links"></a> [vpc\_self\_links](#output\_vpc\_self\_links) | List of VPC self-links |
| <a name="output_vpcs_names"></a> [vpcs\_names](#output\_vpcs\_names) | List of vpcs names |
<!-- END_TF_DOCS -->
