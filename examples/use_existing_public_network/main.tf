/***********************************
      Create Service Acocunt
***********************************/
module "create_service_account" {
  source  = "../../modules/service_account"
  project = var.project
  prefix  = var.prefix
  sa_name = var.sa_name

  providers = {
    google = google.main
  }
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
  set_peering              = var.set_peering
  vpcs                     = var.vpcs
  subnets                  = var.subnets
  zone                     = var.zone
  create_vpc_connector     = var.create_vpc_connector
  vpc_connector_name       = var.vpc_connector_name
  vpc_connector_range      = var.vpc_connector_range
  private_network          = var.private_network
  sg_public_ssh_cidr_range = var.sg_public_ssh_cidr_range

  providers = {
    google = google.deployment
  }

  depends_on = [ module.create_service_account]
}

/***********************************
     Deploy weka cluster
***********************************/
module "deploy_weka" {
  source                   = "../../modules/deploy_weka"
  cluster_name             = var.cluster_name
  project                  = var.project
  nics_number              = var.nics_number
  vpcs                     = var.vpcs
  prefix                   = var.prefix
  region                   = var.region
  subnets_name             = var.subnets
  zone                     = var.zone
  cluster_size             = var.cluster_size
  machine_type             = var.machine_type
  nvmes_number             = var.nvmes_number
  weka_version             = var.weka_version
  weka_username            = var.weka_username
  get_weka_io_token        = var.get_weka_io_token
  internal_bucket_location = var.internal_bucket_location
  weka_image_id          = var.weka_image_id
  vpc_connector            = module.setup_network.output-vpc-connector-name
  sa_email                 = module.create_service_account.outputs-service-account-email
  create_cloudscheduler_sa = var.create_cloudscheduler_sa
  private_network          = var.private_network
  private_dns_zone         = module.setup_network.output-private-zone-name
  private_dns_name         = module.setup_network.output-private-dns-name
  providers = {
    google = google.deployment
  }

  depends_on = [module.create_service_account]
}