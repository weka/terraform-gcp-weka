provider "google" {
  project = var.project_id
  region  = var.region
}

/***********************************
      Create Service Account
***********************************/
module "create_service_account" {
  source            = "../../modules/service_account"
  project_id        = var.project_id
  cluster_name      = var.cluster_name
  obs_name          = var.obs_name
  state_bucket_name = var.state_bucket_name
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

/**********************************************
      Set peering to worker pool
***********************************************/
module "worker_pool" {
  source              = "../../modules/worker_pool"
  project_id          = var.project_id
  region              = var.region
  vpcs                = var.vpcs
  worker_pool_network = var.worker_pool_network
  worker_pool_name    = var.worker_pool_name
  cluster_name        = var.cluster_name
  sa_email            = module.create_service_account.outputs-service-account-email
  depends_on = [module.setup_network]
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
  vpc_connector            = module.setup_network.vpc_connector_name
  sa_email                 = module.create_service_account.outputs-service-account-email
  get_weka_io_token        = var.get_weka_io_token
  private_dns_zone         = module.setup_network.private_zone_name
  private_dns_name         = module.setup_network.private_dns_name
  obs_name                 = var.obs_name
  set_obs_integration      = var.set_obs_integration
  state_bucket_name        = var.state_bucket_name
  worker_pool_name         = var.worker_pool_name
  depends_on               = [module.worker_pool]
}
