provider "google" {
  project = var.project_id
  region  = var.region
}

/***********************************
      Create Service Account
***********************************/
module "create_service_account" {
  source       = "../../modules/service_account"
  project_id   = var.project_id
  prefix       = var.prefix
  cluster_name = var.cluster_name
}

/***********************************
      VPC configuration
***********************************/
module "setup_network" {
  source                   = "../../modules/setup_network"
  project_id               = var.project_id
  region                   = var.region
  vpcs                     = var.vpcs
  subnets                  = var.subnets
  zone                     = var.zone
  vpc_connector_range      = var.vpc_connector_range
}

/***********************************
     Deploy weka cluster
***********************************/
module "deploy_weka" {
  source                   = "../.."
  cluster_name             = var.cluster_name
  project_id               = var.project_id
  vpcs                     = var.vpcs
  region                   = var.region
  subnets_name             = var.subnets
  zone                     = var.zone
  cluster_size             = var.cluster_size
  nvmes_number             = var.nvmes_number
  get_weka_io_token        = var.get_weka_io_token
  vpc_connector            = module.setup_network.vpc_connector_name
  sa_email                 = module.create_service_account.outputs-service-account-email
  private_dns_zone         = module.setup_network.private_zone_name
  private_dns_name         = module.setup_network.private_dns_name
  depends_on               = [module.setup_network]
}
