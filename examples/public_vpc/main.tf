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
}

/***********************************
      VPC configuration
***********************************/
module "setup_network" {
  source              = "../../modules/setup_network"
  project             = var.project
  prefix              = var.prefix
  region              = var.region
  subnets-cidr-range  = var.subnets_cidr_range
  zone                = var.zone
  vpc_connector_range = var.vpc_connector_range
}

/***********************************
     Deploy weka cluster
***********************************/
module "deploy_weka" {
  source            = "../.."
  cluster_name      = var.cluster_name
  project           = var.project
  prefix            = var.prefix
  vpcs              = module.setup_network.vpcs_names
  region            = var.region
  subnets_name      = module.setup_network.subnetwork_name
  zone              = var.zone
  cluster_size      = var.cluster_size
  nvmes_number      = var.nvmes_number
  vpc_connector     = module.setup_network.vpc_connector_name
  sa_email          = module.create_service_account.outputs-service-account-email
  get_weka_io_token = var.get_weka_io_token
  private_dns_zone  = module.setup_network.private_zone_name
  private_dns_name  = module.setup_network.private_dns_name
  weka_version      = var.weka_version
  depends_on        = [module.setup_network]
}