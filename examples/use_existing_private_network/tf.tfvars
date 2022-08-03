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
install_url              = "gs://weka-installation/weka-4.0.0.70-gcp.tar"
machine_type             = "c2-standard-8"
nvmes_number             = 2
weka_version             = "4.0.0.70-gcp"
bucket_location          = "EU"
yum_repo_server          = "http://yum.weka.private.net"
cluster_name             = "poc"
sa_name                  = "deploy-sa"
create_cloudscheduler_sa = true
weka_image_name          = "centos-7-v20220719"
weka_image_project       = "centos-cloud"
