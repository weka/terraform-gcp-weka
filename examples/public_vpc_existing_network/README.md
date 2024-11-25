# Public VPC with exiting VPCs and subnets
This example using exiting vpcs, subnets, service account, private DNS zone, vpc connector
<br>It will use existing vpcs and subnets, but will create all the necessary peering etc.
<br>It will create weka cluster with internet access.
#### You **must** provide network params:
```hcl
vpcs_name           = ["vpc-0","vpc-1","vpc-2","vpc-3"]
subnets_name        = ["subnet-0","subnet-1","subnet-2","subnet-3"]
private_dns_name    = "existing.private.net."
private_zone_name   = "existing-private-zone"
vpc_connector_name  = "existing-connector"
```
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.3.1 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >=6.12.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_weka_deployment"></a> [weka\_deployment](#module\_weka\_deployment) | ../.. | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_get_weka_io_token"></a> [get\_weka\_io\_token](#input\_get\_weka\_io\_token) | Get get.weka.io token for downloading weka | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region name | `string` | `"europe-west1"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_weka_deployment_output"></a> [weka\_deployment\_output](#output\_weka\_deployment\_output) | n/a |
<!-- END_TF_DOCS -->
