### Network module ###
vpcs                 = []
subnets-cidr-range   = ["10.0.0.0/24", "10.1.0.0/24", "10.2.0.0/24", "10.3.0.0/24"]
set_peering          = true
subnets              = []
vpc_connector_range  = "10.8.0.0/28"
create_vpc_connector = true
private_network      = false
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
weka_version             = "3.14.2.3-gcp-beta"
install_url              = ""
cluster_size             = 5
nvmes_number             = 2
machine_type             = "c2-standard-8"
weka_image_name          = "centos-7-v20220719"
weka_image_project       = "centos-cloud"
bucket-location          = "EU"
create_cloudscheduler_sa = true
yum_repo_server          = ""

# Vpcs shared
service_project        = "wekaio-rnd"
host_project           = "test-tf-vars"
shared_vpcs            = ["denise-test-vpc-shard-1", "denise-test-vpc-shard-2"]
create_shared_vpc      = false

### Centos local repo
create_local_repo       = false
family_image            = "centos-7"
project_image           = "centos-cloud"
repo_public_cidr_range  = "10.26.2.0/24"
repo_private_cidr_range = "10.26.1.0/24"