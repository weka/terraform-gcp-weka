<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.2.4 |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.3.1 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >=6.12.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >=6.12.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_project_iam_member.sa_member_role](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_prefix"></a> [prefix](#input\_prefix) | prefix for all resources | `string` | `"weka"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | project id | `string` | `"wekaio-ci"` | no |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | service account name | `string` | `"botty"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
