project                  = "wekaio-ci"
region                   = "europe-west4"
zone                     = "europe-west4-a"
prefix                   = "weka"
subnets_cidr_range       = ["10.0.0.0/24", "10.1.0.0/24", "10.2.0.0/24", "10.3.0.0/24"]
nics_number              = 4
cluster_size             = 7
machine_type             = "c2-standard-8"
nvmes_number             = 2
weka_version             = "4.0.1.37-gcp"
vpc_connector_range      = "10.8.0.0/28"
sa_name                  = "deploy-sa"
cluster_name             = "poc"
sg_public_ssh_cidr_range = ["0.0.0.0/0"]
private_network          = false
