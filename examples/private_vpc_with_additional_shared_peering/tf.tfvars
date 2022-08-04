project                  = "wekaio-rnd"
region                   = "europe-west1"
zone                     = "europe-west1-b"
prefix                   = "weka"
host_project             = "test-tf-vars"
subnets_cidr_range       = ["10.0.0.0/24", "10.1.0.0/24", "10.2.0.0/24", "10.3.0.0/24"]
shared_vpcs              = ["global-test-tf-vars-vpc"]
host_shared_range        = ["10.26.1.0/24"]
nics_number              = 4
cluster_size             = 7
install_url              = "gs://weka-installation/weka-4.0.0.70-gcp.tar"
machine_type             = "c2-standard-8"
nvmes_number             = 2
weka_version             = "4.0.0.70-gcp"
bucket_location          = "EU"
yum_repo_server          = "http://yum.weka.private.net"
vpc_connector_range      = "10.8.0.0/28"
sa_name                  = "deploy-sa"
cluster_name             = "poc"
create_cloudscheduler_sa = true
private_network          = true
weka_image_id          = "projects/centos-cloud/global/images/centos-7-v20220719"
set_peering              = true
create_vpc_connector     = true