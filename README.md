###Prerequisites:
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)

###Weka cluster creation:
- authentication: `gcloud auth application-default login`
- export your project_id: `export TF_VAR_project="YOUR_PROJECT_ID"`
- **only on first run**, create bucket for TF state:`cd bucket && terraform init && terraform apply`
- export your get.weka.io token: `export TF_VAR_get_weka_io_token="YOUR_GET_WEKA_IO_TOKEN"`
- from main repo: `terraform init && terraform apply -auto-approve`
######the variables can be passed as params to tf cli `terraform apply -var 'key1=val1' -var 'key2=val2'` as well

###More info
We allow to pass many variable to `terraform apply`: subnets, region, weka version etc.<br>
There are default values for the parameters.<br>
By default, we create a 5 hosts cluster with 4 nics each. see: `variables.tf`.<br>
The only parameters that **must** be supplied by the user are `get_weka_io_token` and the `project`.
