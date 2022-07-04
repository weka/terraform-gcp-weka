### For network module
vpcs = ["weka-vpc-0","weka-vpc-1","weka-vpc-2","weka-vpc-3"]
set_peering = false
create_vpc_connector = false
vpc_connector_name = "weka-connector"
vpc_connector_range  = "10.8.0.0/28"
subnets = {
    weka-subnet-0 = {
      cidr_range      = "10.0.0.0/24"
      gateway-address = "10.0.0.1"
      vpc-name        = "weka-vpc-0"
    }
    weka-subnet-1 = {
      cidr_range      = "10.1.0.0/24"
      gateway-address = "10.1.0.1"
      vpc-name        = "weka-vpc-1"
    }
    weka-subnet-2 = {
      cidr_range      = "10.2.0.0/24"
      gateway-address = "10.2.0.1"
      vpc-name        = "weka-vpc-2"
    }
    weka-subnet-3 = {
      cidr_range      = "10.3.0.0/24"
      gateway-address = "10.3.0.1"
      vpc-name        = "weka-vpc-3"
    }
}


## Mandatory vars
nics_number  = 4
project      = "wekaio-rnd"
region       = "europe-west1"
zone         = "europe-west1-b"
prefix       = "weka"
cluster_name = "poc"
sa_name      = "deploy-sa"


## Deploy weka module
username = "weka"
get_weka_io_token = ""
weka_version = "3.14.0.50-gcp-beta"
cluster_size = 5
nvmes_number = 2
private_key_filename = ".ssh/google_compute_engine"
machine_type = "c2-standard-8"
weka_username  = ""
bucket-location = "EU"


# Vpcs shared
deploy_on_host_project = false
service_project        = "test-tf-vars"
host_project           = "wekaio-rnd"
shared_vpcs            = ["denise-test-vpc-shard-1", "denise-test-vpc-shard-2"]