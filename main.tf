/***********************************
      Create Service Account
***********************************/
module "create_service_account" {
  source  = "./modules/service_account"
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
  source               = "./modules/setup_network"
  project              = var.project
  nics_number          = var.nics_number
  vpcs                 = var.vpcs
  prefix               = var.prefix
  region               = var.region
  subnets              = var.subnets
  subnets-cidr-range   = var.subnets-cidr-range
  set_peering          = var.set_peering
  zone                 = var.zone
  create_vpc_connector = var.create_vpc_connector
  vpc_connector_range  = var.vpc_connector_range
  vpc_connector_name   = var.vpc_connector_name
  private_network      = var.private_network
  sg_public_ssh_cidr_range = var.sg_public_ssh_cidr_range
  providers = {
    google = google.deployment
  }
  depends_on = [ module.create_service_account]
}

/***********************************
      Shared vpc - host side
***********************************/
module "host_vpc_peering" {
  count                  = var.create_shared_vpc ? 1 : 0
  source                 = "./modules/shared_vpcs"
  deploy_on_host_project = true
  service_project        = var.project
  prefix                 = var.prefix
  project                = var.host_project
  shared_vpcs            = var.shared_vpcs
  vpcs                   = module.setup_network.output-vpcs-names
  providers = {
    google = google.shared-vpc
  }

  depends_on = [module.create_service_account, module.setup_network ]
}

/***********************************
      Shared vpc - service side
***********************************/
module "shared_vpc_peering" {
  count                  = var.create_shared_vpc ? 1 : 0
  source                 = "./modules/shared_vpcs"
  deploy_on_host_project = false
  prefix                 = var.prefix
  project                = var.project
  host_project           = var.host_project
  shared_vpcs            = var.shared_vpcs
  vpcs                   = module.setup_network.output-vpcs-names
  sa_email               = module.create_service_account.outputs-service-account-email
  host_shared_range      = var.host_shared_range
  providers = {
    google = google.deployment
  }
  depends_on = [module.host_vpc_peering, module.setup_network ]
}

/***********************************
     Deploy weka cluster
***********************************/
module "deploy_weka" {
  source                   = "./modules/deploy_weka"
  cluster_name             = var.cluster_name
  project                  = var.project
  nics_number              = var.nics_number
  vpcs                     = module.setup_network.output-vpcs-names
  prefix                   = var.prefix
  region                   = var.region
  subnets_name             = module.setup_network.output-subnetwork-name
  zone                     = var.zone
  cluster_size             = var.cluster_size
  get_weka_io_token        = var.get_weka_io_token
  install_url              = var.install_url
  machine_type             = var.machine_type
  weka_image_name          = var.weka_image_name
  weka_image_project       = var.weka_image_project
  nvmes_number             = var.nvmes_number
  private_network          = var.private_network
  weka_username            = var.weka_username
  weka_version             = var.weka_version
  bucket-location          = var.bucket_location
  vpc_connector            = module.setup_network.output-vpc-connector-name
  sa_email                 = module.create_service_account.outputs-service-account-email
  yum_repo_server          = var.yum_repo_server
  create_cloudscheduler_sa = var.create_cloudscheduler_sa
  private_dns_zone         = module.setup_network.output-private-zone-name
  providers = {
    google = google.deployment
  }

  depends_on = [module.create_service_account, module.setup_network]
}
