### Network module ###
subnets-cidr-range       = ["10.0.0.0/24", "10.1.0.0/24", "10.2.0.0/24", "10.3.0.0/24"]
set_peering              = true
vpc_connector_range      = "10.8.0.0/28"
create_vpc_connector     = true
private_network          = false
sg_public_ssh_cidr_range = ["0.0.0.0/0"]

### Mandatory vars ###
nics_number    = 4
project        = "wekaio-rnd"
region         = "europe-west1"
zone           = "europe-west1-b"
prefix         = "weka"
cluster_name   = "poc"
sa_name        = "deploy-sa"


### Deploy weka module ###
username                 = "weka"
weka_version             = "4.0.0.68-gcp-beta"
cluster_size             = 5
nvmes_number             = 2
machine_type             = "c2-standard-8"
weka_image_name          = "centos-7-v20220719"
weka_image_project       = "centos-cloud"
bucket_location          = "EU"
create_cloudscheduler_sa = true

# Vpcs shared
service_project    = "wekaio-rnd"
host_project       = "test-tf-vars"
shared_vpcs        = ["host-vpc-shared-1", "host-vpc-shared-2"]
create_shared_vpc  = false
host_shared_range  = ["10.13.0.0/24", "10.14.0.0/24"]

### Centos local repo
create_local_repo       = false
repo_image_name         = "centos-7-v20220719"
repo_project_image      = "centos-cloud"
repo_public_cidr_range  = "10.26.2.0/24"
repo_private_cidr_range = "10.26.1.0/24"
vpc_range               = "10.0.0.0/24"