project                  = "wekaio-rnd"
region                   = "europe-west1"
zone                     = "europe-west1-b"
prefix                   = "weka"
vpcs                     = ["weka-vpc-0","weka-vpc-1","weka-vpc-2","weka-vpc-3"]
subnets                  = ["weka-subnet-0","weka-subnet-1","weka-subnet-2","weka-subnet-3"]
create_vpc_connector     = true
vpc_connector_name       = ""
set_peering              = true
vpc_connector_range      = "10.8.0.0/28"
nics_number              = 4
cluster_size             = 7
machine_type             = "c2-standard-8"
nvmes_number             = 2
weka_version             = "4.0.0.70-gcp"
bucket_location          = "EU"
sa_name                  = "deploy-sa"
cluster_name             = "poc"
sg_public_ssh_cidr_range = ["0.0.0.0/0"]
create_cloudscheduler_sa = true
private_network          = false
weka_image_id          = "projects/centos-cloud/global/images/centos-7-v20220719"
