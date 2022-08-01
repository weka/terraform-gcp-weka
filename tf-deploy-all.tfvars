### Network module ###
subnets-cidr-range       = ["10.0.0.0/24", "10.1.0.0/24", "10.2.0.0/24", "10.3.0.0/24"]
set_peering              = true
vpc_connector_range      = "10.8.0.0/28"
create_vpc_connector     = true
private_network          = true
sg_public_ssh_cidr_range = ["0.0.0.0/0"]


### Existing vpcs and subnets
vpcs    = []
subnets = []


### Mandatory vars ###
nics_number    = 4
project        = "wekaio-rnd"
region         = "europe-west1"
zone           = "europe-west1-b"
prefix         = "weka"
cluster_name   = "poc"
sa_name        = "deploy-sa"


### Deploy weka module ###
weka_version             = "4.0.0.70-gcp"
cluster_size             = 5
nvmes_number             = 2
machine_type             = "c2-standard-8"
weka_image_name          = "weka-centos-7"
weka_image_project       = "wekaio-rnd"
bucket_location          = "EU"
create_cloudscheduler_sa = true
yum_repo_server          = ""
install_url              = "gs://weka-installation/weka-4.0.0.70-gcp.tar"

# Vpcs shared
create_shared_vpc  = false
host_project       = "test-tf-vars"
shared_vpcs        = ["global-test-tf-vars-vpc"]
host_shared_range  = ["10.26.1.0/24", "10.26.2.0/24"]
