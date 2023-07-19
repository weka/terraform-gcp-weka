provider "google" {
  project = var.project_id
  region  = var.region
}

/***********************************
      Create Service Account
***********************************/
module "create_service_account" {
  source     = "../../modules/service_account"
  project_id = var.project_id
}

/***********************************
      VPC configuration
***********************************/
module "setup_network" {
  source                   = "../../modules/setup_network"
  project_id               = var.project_id
  region                   = var.region
  subnets-cidr-range       = var.subnets_cidr_range
  zone                     = var.zone
  vpc_connector_range      = var.vpc_connector_range
}

/**********************************************
      Create worker pool for cloud functions
***********************************************/
module "create_worker_pool" {
  source              = "../../modules/worker_pool"
  project_id          = var.project_id
  region              = var.region
  vpcs                = module.setup_network.vpcs_names
  cluster_name        = var.cluster_name
  sa_email            = module.create_service_account.outputs-service-account-email
  depends_on          = [module.setup_network]
}

/***********************************
     Deploy weka cluster
***********************************/
module "deploy_weka" {
  source                   = "../.."
  cluster_name             = var.cluster_name
  project_id               = var.project_id
  vpcs                     = module.setup_network.vpcs_names
  region                   = var.region
  subnets_name             = module.setup_network.subnetwork_name
  zone                     = var.zone
  cluster_size             = var.cluster_size
  nvmes_number             = var.nvmes_number
  vpc_connector            = module.setup_network.vpc_connector_name
  sa_email                 = module.create_service_account.outputs-service-account-email
  get_weka_io_token        = var.get_weka_io_token
  private_dns_zone         = module.setup_network.private_zone_name
  private_dns_name         = module.setup_network.private_dns_name
  worker_pool_name         = module.create_worker_pool.worker_pool
  depends_on               = [module.create_worker_pool]

}
