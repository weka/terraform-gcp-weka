
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
| [google_project_iam_member.sa-member-role](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_key.sa-key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_prefix"></a> [prefix](#input\_prefix) | prefix for all resources | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | project id | `string` | n/a | yes |
| <a name="input_sa_name"></a> [sa\_name](#input\_sa\_name) | service account name | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_output-sa-key"></a> [output-sa-key](#output\_output-sa-key) | n/a |
| <a name="output_outputs-service-account-email"></a> [outputs-service-account-email](#output\_outputs-service-account-email) | n/a |
