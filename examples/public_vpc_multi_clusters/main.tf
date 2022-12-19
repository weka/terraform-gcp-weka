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
  source                   = "../../modules/setup_network"
  project                  = var.project
  nics_number              = var.nics_number
  prefix                   = var.prefix
  region                   = var.region
  subnets-cidr-range       = var.subnets_cidr_range
  zone                     = var.zone
  vpc_connector_range      = var.vpc_connector_range
  private_network          = var.private_network
  sg_public_ssh_cidr_range = var.sg_public_ssh_cidr_range
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
  machine_type             = var.machine_type
  nvmes_number             = var.nvmes_number
  weka_username            = var.weka_username
  weka_version             = var.weka_version
  internal_bucket_location = var.internal_bucket_location
  vpc_connector            = module.setup_network.vpc_connector_name
  sa_email                 = module.create_service_account.outputs-service-account-email
  get_weka_io_token        = var.get_weka_io_token
  private_network          = var.private_network
  private_dns_zone         = module.setup_network.private_zone_name
  private_dns_name         = module.setup_network.private_dns_name
  depends_on               = [module.setup_network]
}