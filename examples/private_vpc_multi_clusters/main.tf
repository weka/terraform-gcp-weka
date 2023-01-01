provider "google" {
  project = var.project
  region  = var.region
}

/***********************************
      Create Service Account
***********************************/
module "create_service_account" {
  source  = "../../modules/service_account"
  project = var.project
  prefix  = var.prefix
  sa_name = var.sa_name
}

/***********************************
      VPC configuration
***********************************/
module "setup_network" {
  source               = "../../modules/setup_network"
  project              = var.project
  nics_number          = var.nics_number
  prefix               = var.prefix
  region               = var.region
  subnets-cidr-range   = var.subnets_cidr_range
  zone                 = var.zone
  vpc_connector_range  = var.vpc_connector_range
  private_network      = var.private_network
}

/***********************************
     Deploy weka cluster
***********************************/
module "deploy_weka" {
  count                    = length(var.clusters_name)
  source                   = "../.."
  cluster_name             = var.clusters_name[count.index]
  project                  = var.project
  nics_number              = var.nics_number
  vpcs                     = module.setup_network.vpcs_names
  prefix                   = var.prefix
  region                   = var.region
  subnets_name             = module.setup_network.subnetwork_name
  zone                     = var.zone
  cluster_size             = var.cluster_size
  install_url              = var.install_url
  machine_type             = var.machine_type
  nvmes_number             = var.nvmes_number
  weka_version             = var.weka_version
  weka_username            = var.weka_username
  vpc_connector            = module.setup_network.vpc_connector_name
  sa_email                 = module.create_service_account.outputs-service-account-email
  yum_repo_server          = var.yum_repo_server
  private_network          = var.private_network
  private_dns_zone         = module.setup_network.private_zone_name
  private_dns_name         = module.setup_network.private_dns_name
  depends_on               = [module.setup_network]
}