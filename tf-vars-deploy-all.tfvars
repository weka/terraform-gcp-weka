### Network module ###
vpcs                 = []
subnets-cidr-range   = ["10.0.0.0/24", "10.1.0.0/24", "10.2.0.0/24", "10.3.0.0/24"]
set_peering          = true
subnets              = {}
vpc_connector_range  = "10.8.0.0/28"
create_vpc_connector = true
vpc_connector_name   = ""


### Mandatory vars ###
nics_number    = 4
project        = "wekaio-rnd"
project_number = "896245720241"
region         = "europe-west1"
zone           = "europe-west1-b"
prefix         = "weka"
cluster_name   = "poc"
sa_name        = "deploy-sa"


### Deploy weka module ###
username                 = "weka"
weka_version             = "3.14.0.50-gcp-beta"
cluster_size             = 5
nvmes_number             = 2
private_key_filename     = ".ssh/google_compute_engine"
machine_type             = "c2-standard-8"
bucket-location          = "EU"
create_cloudscheduler_sa = true

# Vpcs shared
deploy_on_host_project = false
service_project        = "test-tf-vars"
host_project           = "wekaio-rnd"
shared_vpcs            = ["denise-test-vpc-shard-1", "denise-test-vpc-shard-2"]