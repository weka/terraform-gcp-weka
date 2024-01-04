# Public VPC with shared vpcs
This example creates service account for weka deployment,
<br>all the network resources needed for weka deployment, including vpcs, peering, etc.
<br>weka cluster with internet and peering to a vpc in different project.

## Usage
```hcl
shared_vpcs        = [".."]
host_project       = HOST_PROJECT_ID
host_shared_range  = [".."]
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
| <a name="module_weka_deployment"></a> [weka\_deployment](#module\_weka\_deployment) | ../.. | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_get_weka_io_token"></a> [get\_weka\_io\_token](#input\_get\_weka\_io\_token) | Get get.weka.io token for downloading weka | `string` | n/a | yes |
| <a name="input_host_project"></a> [host\_project](#input\_host\_project) | The ID of the project that will serve as a Shared VPC host project | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region name | `string` | `"europe-west1"` | no |
| <a name="input_shared_vpc_project_id"></a> [shared\_vpc\_project\_id](#input\_shared\_vpc\_project\_id) | Shared vpc project id | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_weka_deployment_output"></a> [weka\_deployment\_output](#output\_weka\_deployment\_output) | n/a |
<!-- END_TF_DOCS -->
