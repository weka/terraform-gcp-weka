### For network module
vpcs                 = ["weka-vpc-0","weka-vpc-1","weka-vpc-2","weka-vpc-3"]
set_peering          = true
create_vpc_connector = true
vpc_connector_range  = "10.8.0.0/28"
vpc_connector_name   = "weka-connector"
subnets              = ["weka-subnet-0","weka-subnet-1","weka-subnet-2","weka-subnet-3"]

## Mandatory vars
nics_number  = 4
project      = "wekaio-rnd"
region       = "europe-west1"
zone         = "europe-west1-b"
prefix       = "weka"
cluster_name = "poc"
sa_name      = "deploy-sa"


## Deploy weka module
username                 = "weka"
private_network          = false
weka_version             = "4.0.0.68-gcp-beta"
install_url              = ""
cluster_size             = 5
nvmes_number             = 2
machine_type             = "c2-standard-8"
weka_image_name          = "centos-7-v20220719"
weka_image_project       = "centos-cloud"
bucket-location          = "EU"
yum_repo_server          = ""
create_cloudscheduler_sa = true


# Vpcs shared
service_project        = "wekaio-rnd"
host_project           = "test-tf-vars"
shared_vpcs            = ["denise-test-vpc-shard-1", "denise-test-vpc-shard-2"]
create_shared_vpc      = true

### Centos local repo
create_local_repo       = false
family_image            = "centos-7"
project_image           = "centos-cloud"
repo_public_cidr_range  = "10.26.2.0/24"
repo_private_cidr_range = "10.26.1.0/24"