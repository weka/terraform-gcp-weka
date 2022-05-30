###Prerequisites:
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)

###Weka cluster creation:
- authentication: `gcloud auth application-default login`
- **only on first run**, create bucket for TF state:`cd bucket && terraform init && terraform apply`
- export your get.weka.io token: `export TF_VAR_get_weka_io_token="YOUR_GET_WEKA_IO_TOKEN"`
- from main repo: `terraform init && terraform apply -auto-approve`
######the get_weka_io can be passed as var `terraform apply -var 'get_weka_io=value'` as well

###More info
We allow to pass many variable to `terraform apply`: subnets, region, weka version etc.<br>
There are default values for the parameters.<br>
By default, we create a 5 hosts cluster with 4 nics each. see: `variables.tf`.<br>
The only parameter that **must** be supplied by the user is `get_weka_io_token`.
