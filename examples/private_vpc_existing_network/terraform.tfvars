project_id              = "wekaio-rnd"
region                  = "europe-west1"
zone                    = "europe-west1-b"
vpcs                    = ["weka-vpc-0","weka-vpc-1","weka-vpc-2","weka-vpc-3"]
subnets                 = ["weka-subnet-0","weka-subnet-1","weka-subnet-2","weka-subnet-3"]
vpc_connector_range     = "10.8.0.0/28"
cluster_size            = 7
install_url             = "gs://weka-installation/weka-4.0.1.37-gcp.tar"
nvmes_number            = 2
yum_repo_server         = "http://yum.weka.private.net"
cluster_name            = "poc"
private_network         = true
