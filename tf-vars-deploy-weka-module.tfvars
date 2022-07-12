### For network module
vpcs_list            = ["denise-vpc-0","denise-vpc-1","denise-vpc-2","denise-vpc-3"]
set_peering          = true
create_vpc_connector = true
vpc_connector_name   = "denise-connector"
vpc_connector_range  = "11.8.0.0/28"
subnets              = ["denise-subnet-0","denise-subnet-1","denise-subnet-2","denise-subnet-3"]



## Mandatory vars
vpc_number               = 4
project                  = "test-tf-vars"
project_number           = "1053406525470"
region                   = "us-east1"
zone                     = "us-east1-b"
prefix                   = "denise"
cluster_name             = "test"
sa_name                  = "deploy-sa"
create_cloudscheduler_sa = true


## Deploy weka module
username        = "weka"
weka_version    = "3.14.0.50-gcp-beta"
install_url     = "gs://weka-installation/weka-3.14.0.50-gcp-beta.tar"
cluster_size    = 5
nvmes_number    = 2
machine_type    = "c2-standard-8"
weka_username   = ""
bucket_location = "EU"
yum_repo_server = "http://yum.weka.private.net"

# Vpcs shared
deploy_on_host_project = true
service_project        = "wekaio-rnd"
host_project           = "test-tf-vars"
shared_vpcs            = ["denise-test-vpc-shard-1", "denise-test-vpc-shard-2"]
create_shared_vpc      = true